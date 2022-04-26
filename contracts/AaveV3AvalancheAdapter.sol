// solhint-disable no-unused-vars
// SPDX-License-Identifier:MIT

pragma solidity =0.8.11;
pragma experimental ABIEncoderV2;

//  libraries
import { Address } from "@openzeppelin/contracts-0.8.x/utils/Address.sol";
import { ERC20 } from "@openzeppelin/contracts-0.8.x/token/ERC20/ERC20.sol";

//  helper contracts
import { AdapterModifiersBase } from "./utils/AdapterModifiersBase.sol";
import "./utils/AdapterInvestLimitBase.sol";

//  interfaces
import {
    IAaveV3LendingPoolAddressesProvider
} from "@optyfi/defi-legos/avalanche/aavev3/contracts/IAaveV3LendingPoolAddressesProvider.sol";
import {
    IAaveV3LendingPoolAddressesProviderRegistry
} from "@optyfi/defi-legos/avalanche/aavev3/contracts/IAaveV3LendingPoolAddressesProviderRegistry.sol";
import { IAaveV3, ReserveData } from "@optyfi/defi-legos/avalanche/aavev3/contracts/IAaveV3.sol";
import { IAaveV3Token } from "@optyfi/defi-legos/avalanche/aavev3/contracts/IAaveV3Token.sol";
import {
    IAaveV3ProtocolDataProvider
} from "@optyfi/defi-legos/avalanche/aavev3/contracts/IAaveV3ProtocolDataProvider.sol";
import { IAaveV3RewardsController } from "@optyfi/defi-legos/avalanche/aavev3/contracts/IAaveV3RewardsController.sol";
import { IAdapter } from "@optyfi/defi-legos/interfaces/defiAdapters/contracts/IAdapter.sol";
import { IAdapterHarvestReward } from "@optyfi/defi-legos/interfaces/defiAdapters/contracts/IAdapterHarvestReward.sol";
import "@optyfi/defi-legos/interfaces/defiAdapters/contracts/IAdapterInvestLimit.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

/**
 * @title Adapter for Aave V3 protocol
 * @author Opty.fi
 * @dev Abstraction layer to Aave's pools
 */
contract AaveV3AvalancheAdapter is IAdapter, IAdapterHarvestReward, AdapterInvestLimitBase {
    using Address for address;

    /** @notice Aave's Data provider id */
    bytes32 public constant PROTOCOL_DATA_PROVIDER_ID =
        0x0100000000000000000000000000000000000000000000000000000000000000;

    /**
     * @notice Trader Joe router contract address
     */
    address public constant traderJoeRouter = address(0x60aE616a2155Ee3d9A68541Ba4544862310933d4);

    /**@notice PoS WAVAX */
    address public constant WAVAX = address(0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7);

    /**@notice incentivesController*/
    address public constant incentivesController = address(0x929EC64c34a17401F460460D4B9390518E5B473e);

    /**
     * @notice the A tokens list that is used for claiming reward token
     */
    address[] public aaveAssetsList;

    /* solhint-disable no-empty-blocks */
    constructor(address _registry) AdapterModifiersBase(_registry) {
        aaveAssetsList.push(address(0x82E64f49Ed5EC1bC6e43DAD4FC8Af9bb3A2312EE)); //ADai
        aaveAssetsList.push(address(0x191c10Aa4AF7C30e871E70C95dB0E4eb77237530)); //ALINK
        aaveAssetsList.push(address(0x625E7708f30cA75bfd92586e17077590C60eb4cD)); //AUSDC
        aaveAssetsList.push(address(0x078f358208685046a11C85e8ad32895DED33A249)); // AWBTC
        aaveAssetsList.push(address(0xe50fA9b3c56FfB159cB0FCA61F5c9D750e8128c8)); // AWETH
        aaveAssetsList.push(address(0x6ab707Aca953eDAeFBc4fD23bA73294241490620)); // AUSDT
        aaveAssetsList.push(address(0xf329e36C7bF6E5E86ce2150875a84Ce77f477375)); // AAAVE
        aaveAssetsList.push(address(0x6d80113e533a2C0fe82EaBD35f1875DcEA89Ea97)); // AWAVAX
    }

    /**
     * @notice Set Aave assets list to claim reward token.
     * @param _assets the list of assets
     */
    function setAaveAssetsList(address[] memory _assets) external onlyOperator {
        delete aaveAssetsList;
        for (uint256 _i; _i < _assets.length; _i++) {
            aaveAssetsList.push(_assets[_i]);
        }
    }

    /**
     * @dev AaveV3 allows user to get mutiple reward tokens
     * @notice Returns reward tokens list for the liquidity pool provided
     * @return Returns the reward tokens list
     */
    function getRewardTokens() public view returns (address[] memory) {
        return IAaveV3RewardsController(incentivesController).getRewardsList();
    }

    /**
     * @inheritdoc IAdapter
     */
    function getRewardToken(address) public view override returns (address) {
        return IAaveV3RewardsController(incentivesController).getRewardsList()[0];
    }

    /**
     * @inheritdoc IAdapter
     */
    function getLiquidityPoolToken(address _underlyingToken, address _liquidityPoolAddressProviderRegistry)
        public
        view
        override
        returns (address)
    {
        address _lendingPool = _getLendingPool(_liquidityPoolAddressProviderRegistry);
        ReserveData memory _reserveData = IAaveV3(_lendingPool).getReserveData(_underlyingToken);
        return _reserveData.aTokenAddress;
    }

    /**
     * @inheritdoc IAdapter
     */
    function getAllAmountInToken(
        address payable _vault,
        address _underlyingToken,
        address _liquidityPoolAddressProviderRegistry
    ) public view override returns (uint256) {
        return getLiquidityPoolTokenBalance(_vault, _underlyingToken, _liquidityPoolAddressProviderRegistry);
    }

    /**
     * @inheritdoc IAdapter
     */
    function getLiquidityPoolTokenBalance(
        address payable _vault,
        address _underlyingToken,
        address _liquidityPoolAddressProviderRegistry
    ) public view override returns (uint256) {
        return ERC20(getLiquidityPoolToken(_underlyingToken, _liquidityPoolAddressProviderRegistry)).balanceOf(_vault);
    }

    /**
     * @inheritdoc IAdapter
     */
    function getPoolValue(address _liquidityPoolAddressProviderRegistry, address _underlyingToken)
        public
        view
        override
        returns (uint256)
    {
        return
            ERC20(_underlyingToken).balanceOf(
                getLiquidityPoolToken(_underlyingToken, _liquidityPoolAddressProviderRegistry)
            );
    }

    /**
     * @inheritdoc IAdapter
     */
    function getDepositSomeCodes(
        address payable _vault,
        address _underlyingToken,
        address _liquidityPoolAddressProviderRegistry,
        uint256 _amount
    ) public view override returns (bytes[] memory _codes) {
        uint256 _depositAmount =
            _getDepositAmount(
                _liquidityPoolAddressProviderRegistry,
                _underlyingToken,
                _amount,
                getPoolValue(_liquidityPoolAddressProviderRegistry, _underlyingToken)
            );
        require(_depositAmount > 0, "!amount");

        address _lendingPool = _getLendingPool(_liquidityPoolAddressProviderRegistry);
        _codes = new bytes[](3);
        _codes[0] = abi.encode(
            _underlyingToken,
            abi.encodeWithSignature("approve(address,uint256)", _lendingPool, uint256(0))
        );
        _codes[1] = abi.encode(
            _underlyingToken,
            abi.encodeWithSignature("approve(address,uint256)", _lendingPool, _depositAmount)
        );
        _codes[2] = abi.encode(
            _lendingPool,
            abi.encodeWithSignature(
                "supply(address,uint256,address,uint16)",
                _underlyingToken,
                _depositAmount,
                _vault,
                uint16(0)
            )
        );
    }

    /**
     * @inheritdoc IAdapter
     */
    function getWithdrawSomeCodes(
        address payable _vault,
        address _underlyingToken,
        address _liquidityPoolAddressProviderRegistry,
        uint256 _amount
    ) public view override returns (bytes[] memory _codes) {
        require(_amount > 0, "!amount");
        address _lendingPool = _getLendingPool(_liquidityPoolAddressProviderRegistry);
        address _liquidityPoolToken = getLiquidityPoolToken(_underlyingToken, _liquidityPoolAddressProviderRegistry);
        _codes = new bytes[](3);
        _codes[0] = abi.encode(
            _liquidityPoolToken,
            abi.encodeWithSignature("approve(address,uint256)", _lendingPool, uint256(0))
        );
        _codes[1] = abi.encode(
            _liquidityPoolToken,
            abi.encodeWithSignature("approve(address,uint256)", _lendingPool, _amount)
        );
        _codes[2] = abi.encode(
            _lendingPool,
            abi.encodeWithSignature("withdraw(address,uint256,address)", _underlyingToken, _amount, _vault)
        );
    }

    /**
     * @inheritdoc IAdapterHarvestReward
     */
    function getHarvestSomeCodes(
        address payable _vault,
        address _underlyingToken,
        address,
        uint256 _rewardTokenAmount
    ) public view override returns (bytes[] memory _codes) {
        return _getHarvestCodes(_vault, getRewardToken(address(0)), _underlyingToken, _rewardTokenAmount);
    }

    /**
     * @inheritdoc IAdapterHarvestReward
     */
    function getUnclaimedRewardTokenAmount(
        address payable _vault,
        address,
        address
    ) public view override returns (uint256 _amount) {
        if (aaveAssetsList.length > 0) {
            return (
                IAaveV3RewardsController(incentivesController).getUserRewards(
                    aaveAssetsList,
                    _vault,
                    getRewardToken(address(0))
                )
            );
        }
    }

    /**
     * @notice Get unclaimed reward token amounts
     * @param _vault the address of vault
     * @return rewardsList the list of reward tokens
     * @return unclaimedAmounts the list of unclaimed amounts
     */
    function getUnclaimedRewardTokensAmount(address payable _vault)
        public
        view
        returns (address[] memory rewardsList, uint256[] memory unclaimedAmounts)
    {
        if (aaveAssetsList.length > 0) {
            return (IAaveV3RewardsController(incentivesController).getAllUserRewards(aaveAssetsList, _vault));
        }
    }

    /**
     * @inheritdoc IAdapter
     */
    function getDepositAllCodes(
        address payable _vault,
        address _underlyingToken,
        address _liquidityPoolAddressProviderRegistry
    ) external view override returns (bytes[] memory) {
        uint256 _amount = ERC20(_underlyingToken).balanceOf(_vault);
        return getDepositSomeCodes(_vault, _underlyingToken, _liquidityPoolAddressProviderRegistry, _amount);
    }

    /**
     * @inheritdoc IAdapter
     */
    function getWithdrawAllCodes(
        address payable _vault,
        address _underlyingToken,
        address _liquidityPoolAddressProviderRegistry
    ) external view override returns (bytes[] memory) {
        uint256 _redeemAmount =
            getLiquidityPoolTokenBalance(_vault, _underlyingToken, _liquidityPoolAddressProviderRegistry);
        return getWithdrawSomeCodes(_vault, _underlyingToken, _liquidityPoolAddressProviderRegistry, _redeemAmount);
    }

    /**
     * @inheritdoc IAdapter
     */
    function getUnderlyingTokens(address, address _liquidityPoolToken)
        public
        view
        override
        returns (address[] memory _underlyingTokens)
    {
        _underlyingTokens = new address[](1);
        _underlyingTokens[0] = IAaveV3Token(_liquidityPoolToken).UNDERLYING_ASSET_ADDRESS();
    }

    /**
     * @inheritdoc IAdapter
     */
    function getSomeAmountInToken(
        address,
        address,
        uint256 _liquidityPoolTokenAmount
    ) external pure override returns (uint256) {
        return _liquidityPoolTokenAmount;
    }

    /**
     * @inheritdoc IAdapter
     */
    function calculateAmountInLPToken(
        address,
        address,
        uint256 _underlyingTokenAmount
    ) external pure override returns (uint256) {
        return _underlyingTokenAmount;
    }

    /**
     * @inheritdoc IAdapter
     */
    function calculateRedeemableLPTokenAmount(
        address payable,
        address,
        address,
        uint256 _redeemAmount
    ) external pure override returns (uint256) {
        return _redeemAmount;
    }

    /**
     * @inheritdoc IAdapter
     */
    function isRedeemableAmountSufficient(
        address payable _vault,
        address _underlyingToken,
        address _liquidityPoolAddressProviderRegistry,
        uint256 _redeemAmount
    ) external view override returns (bool) {
        uint256 _balanceInToken = getAllAmountInToken(_vault, _underlyingToken, _liquidityPoolAddressProviderRegistry);
        return _balanceInToken >= _redeemAmount;
    }

    /**
     * @inheritdoc IAdapter
     */
    function canStake(address) external pure override returns (bool) {
        return false;
    }

    /**
     * @inheritdoc IAdapterHarvestReward
     */
    function getClaimRewardTokenCode(address payable _vault, address)
        external
        view
        override
        returns (bytes[] memory _codes)
    {
        if (aaveAssetsList.length > 0) {
            _codes = new bytes[](1);
            _codes[0] = abi.encode(
                incentivesController,
                abi.encodeWithSignature("claimAllRewards(address[],address)", aaveAssetsList, _vault)
            );
        }
    }

    /*solhint-disable  no-empty-blocks*/
    /**
     * @inheritdoc IAdapterHarvestReward
     */
    function getAddLiquidityCodes(address payable _vault, address _underlyingToken)
        external
        view
        override
        returns (bytes[] memory _codes)
    {}

    /**
     * @inheritdoc IAdapterHarvestReward
     */
    function getHarvestAllCodes(
        address payable _vault,
        address _underlyingToken,
        address
    ) external view override returns (bytes[] memory _codes) {
        uint256 _rewardTokenAmount = ERC20(getRewardToken(address(0))).balanceOf(_vault);
        return getHarvestSomeCodes(_vault, _underlyingToken, address(0), _rewardTokenAmount);
    }

    function _getLendingPool(address _lendingPoolAddressProviderRegistry) internal view returns (address) {
        return
            IAaveV3LendingPoolAddressesProvider(_getLendingPoolAddressProvider(_lendingPoolAddressProviderRegistry))
                .getPool();
    }

    function _getLendingPoolAddressProvider(address _liquidityPoolAddressProviderRegistry)
        internal
        view
        returns (address)
    {
        return
            IAaveV3LendingPoolAddressesProviderRegistry(_liquidityPoolAddressProviderRegistry)
                .getAddressesProvidersList()[0];
    }

    function _getProtocolDataProvider(address _liquidityPoolAddressProviderRegistry) internal view returns (address) {
        return
            IAaveV3LendingPoolAddressesProvider(_getLendingPoolAddressProvider(_liquidityPoolAddressProviderRegistry))
                .getAddress(PROTOCOL_DATA_PROVIDER_ID);
    }

    /**
     * @dev Get the codes for harvesting the tokens using quickswap like routers-i.e. swapping back into the underlying
     * @param _vault Vault contract address
     * @param _rewardToken Reward token address
     * @param _underlyingToken Token address acting as underlying Asset for the vault contract
     * @param _rewardTokenAmount reward token amount to harvest
     * @return _codes List of harvest codes for harvesting reward tokens
     */
    function _getHarvestCodes(
        address payable _vault,
        address _rewardToken,
        address _underlyingToken,
        uint256 _rewardTokenAmount
    ) internal view returns (bytes[] memory _codes) {
        if (_rewardTokenAmount > 0) {
            uint256[] memory _amounts =
                IUniswapV2Router02(traderJoeRouter).getAmountsOut(
                    _rewardTokenAmount,
                    _getPath(_rewardToken, _underlyingToken)
                );
            if (_amounts[_amounts.length - 1] > 0) {
                _codes = new bytes[](3);
                _codes[0] = abi.encode(
                    _rewardToken,
                    abi.encodeCall(ERC20(_rewardToken).approve, (traderJoeRouter, uint256(0)))
                );
                _codes[1] = abi.encode(
                    _rewardToken,
                    abi.encodeCall(ERC20(_rewardToken).approve, (traderJoeRouter, _rewardTokenAmount))
                );
                _codes[2] = abi.encode(
                    traderJoeRouter,
                    abi.encodeCall(
                        IUniswapV2Router01(traderJoeRouter).swapExactTokensForTokens,
                        (
                            _rewardTokenAmount,
                            uint256(0),
                            _getPath(_rewardToken, _underlyingToken),
                            _vault,
                            type(uint256).max
                        )
                    )
                );
            }
        }
    }

    /**
     * @dev Constructs the path for token swap on Uniswap
     * @param _initialToken The token to be swapped with
     * @param _finalToken The token to be swapped for
     * @return _path The array of tokens in the sequence to be swapped for
     */
    function _getPath(address _initialToken, address _finalToken) internal pure returns (address[] memory _path) {
        if (_finalToken == WAVAX) {
            _path = new address[](2);
            _path[0] = _initialToken;
            _path[1] = WAVAX;
        } else if (_initialToken == WAVAX) {
            _path = new address[](2);
            _path[0] = WAVAX;
            _path[1] = _finalToken;
        } else {
            _path = new address[](3);
            _path[0] = _initialToken;
            _path[1] = WAVAX;
            _path[2] = _finalToken;
        }
    }
}
