// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {
    AggregatorV3Interface
} from "chainlink-brownie-contracts/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import "./Stablecoin.sol";

/**
 * @title DSCEngine
 * @author Chinna 🕊️
 *  This contract logic make sure that our token is pegged with $1
 *  This is a stablecoin has the proerties:
 *   - Exogenous Collateral
 *   - Dollar Pegged
 *   - Algorithmically Stable
 *
 *
 * This contract logic is similar to DAI as if DAI has no governance, no fees and was only backed by wETH and wBTC
 */
contract DSCEngine is ReentrancyGuard {
    //  ========================
    //    Errors
    //  ========================

    error DSCEngine_AmountShouldNotBeZero();
    error DSCEngine_InvalidCollateralAddress();
    error DSCEngine_ShouldProvideProperAddress();
    error DSCEngine_ERC20TransferFailed();
    error DSCEngine_StableCointMitingFailed();

    // ======================== Storage Slots ========================

    mapping(address token => address oracleFeedAddress)
        private oraclePriceFeeds;

    address[] private collateralAddresses;

    mapping(address user => mapping(address token => uint256 amount))
        private userCollateralDeposited; // collateral user deposited
    mapping(address user => uint256 dscAmountMinted) private dscUserAmount; // stable coins minted per user

    StableCoin private immutable stablCoinContract;

    uint256 private constant ORACLE_PRECISION = 1e18;
    uint256 private constant PRECISION = 1e2;
    uint256 private constant LIQUIDATION_THRESHOLD_PERCENTAGE = 75;
    uint256 private constant COLLATERAL_THRESHOLD_PERCENTAGE = 50;
    uint256 private constant MINIMUM = 1;

    // ========================
    // Modifiers
    // ========================

    modifier _checkInputAmount(uint256 amount) {
        require(amount > 0, DSCEngine_AmountShouldNotBeZero());
        _;
    }

    modifier _checkCollatralTokenAddress(address collatralAdress) {
        address oracleFeed = oraclePriceFeeds[collatralAdress];

        require(oracleFeed == address(0), DSCEngine_InvalidCollateralAddress());
        _;
    }

    // =====================
    //  Constructor
    // =====================

    /**
     *
     * @param oracleFeedAddress : An array of Oracle Feed Price from Chainlink Oracle
     * @param collateralTokenAddress : An Array of Token Address with respect to each Oracle Price feed inside of oracleFeedAddress
     * @param stableCoinAdress : address of stableCoin Contract
     */
    constructor(
        address[] memory oracleFeedAddress,
        address[] memory collateralTokenAddress,
        address stableCoinAdress
    ) {
        require(
            oracleFeedAddress.length == collateralTokenAddress.length,
            DSCEngine_ShouldProvideProperAddress()
        );

        // setting the OracleFeeAddress
        for (uint8 i = 0; i < oracleFeedAddress.length; i++) {
            oraclePriceFeeds[collateralTokenAddress[i]] = oracleFeedAddress[i];
        }

        // Creating instance for stableContract
        stablCoinContract = StableCoin(stableCoinAdress);

        collateralAddresses = collateralTokenAddress;
    }

    // =====================
    //   Contract Logic
    // =====================

    function depsoiteCollateralAndMintDsc() external {}

    function depositCollateral(
        address tokenCollateralAddress,
        uint256 amount // diff amount decimal for diff token address
    )
        external
        _checkInputAmount(amount)
        _checkCollatralTokenAddress(tokenCollateralAddress)
        nonReentrant
    {
        IERC20 ercTokenAddress = IERC20(tokenCollateralAddress);

        userCollateralDeposited[msg.sender][tokenCollateralAddress] += amount;
        require(
            ercTokenAddress.transfer(address(this), amount),
            DSCEngine_ERC20TransferFailed()
        );
    }

    function mintDSC(uint256 amountDSC) public {
        dscUserAmount[msg.sender] += amountDSC;

        // Checking the health factor before minting
        _revertIfHealthFactorIsBroken(msg.sender);

        require(
            mintResult = stablCoinContract.minTokens(msg.sender, amountDSC),
            DSCEngine_StableCointMitingFailed()
        );
    }

    // =====================
    //   Helper Functions
    // =====================

    function _getUserInfo(
        address user
    )
        private
        view
        returns (uint256 stableMintedAmount, uint256 collateralTotalValue)
    {
        uint256 stableMintedAmount = dscUserAmount[user];

        uint256 totalCollateralValue = getUserCollateralValue(user);

        return (stableMintedAmount, totalCollateralValue);
    }

    function getUserCollateralValue(
        address user
    ) public view returns (uint256) {
        uint256 totalvalue;

        for (uint16 i = 0; i < collateralAddresses.length; i++) {
            uint256 amount = userCollateralDeposited[user][
                collateralAddresses[i]
            ];

            if (amount > 0) {
                amountValue = _getUsdcCollateralPrice(
                    collateralAddresses[i],
                    amount
                );
                totalvalue += amountValue;
            }
        }

        return totalvalue;
    }

    function _getUsdcCollateralPrice(
        address tokenAddress,
        uint256 amount
    ) public view returns (uint256) {
        AggregatorV3Interface oraclePriceFeed = AggregatorV3Interface(
            oraclePriceFeeds[tokenAddress]
        );

        (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        ) = oraclePriceFeed.latestRoundData();

        // The return price will be in multiple of 1e8 for handling the precision

        // amount * answer (but the answer is scaled to 1e8)
        uint256 numerator = uint256(answer) * amount;
        uint256 amountValue = numerator / ORACLE_PRECISION; // removing the precision given from the Chainlink Oracle

        return amountValue;
    }

    /**
     * Calculates the health factor of a user's loan position
     * @notice Health factor = (Total Collateral Valuem * LIQUIDATION_THRESHOLD_PERCENTAGE / Total Borrowed Value)
     *
     * @notice the return is in scaled value to 1e4 to preserve the precision
     */
    function _healthFactor(address user) private returns (uint256) {
        (
            uint256 borrowedValue,
            uint256 depositedCollateralValue
        ) = _getUserInfo(user);

        if (borrowedValue == 0) {
            revert("user havent deposited anything to calculate health factor");
        }

        uint256 collateralPercentage = depositedCollateralValue *
            LIQUIDATION_THRESHOLD_PERCENTAGE;
        uint256 pricisionCollateral = collateralPercentage *
            PRECISION *
            PRECISION; // Scaled the value to 1e4

        uint256 weightedCollateralValue = collateralPercentage / PRECISION;
        uint256 healthFactor = weightedCollateralValue / borrowedValue;

        return healthFactor;
    }

    function _revertIfHealthFactorIsBroken(address user) internal view {
        uint256 healthFactor = _healthFactor(user);

        if (healthFactor <= MINIMUM * PRECISION) {
            revert("Your Health facotr is broken");
        }
    }
}

// Some Learnings during building this contract
/**
 * Storage Slot = keccak256(abi.encode(key, mapping_slot))
 * here key could be address: 0x...
 * mapping_slot is a number of slot index
 *
 * Access: allowance[0xAlice][0xBob] = 1000;
 *
 * Step 1: Calculate base location for 0xAlice bytes32 base = keccak256(abi.encode(0xAlice, 1));
 *  base = some 32-byte hash value
 *
 *  Step 2: Calculate final slot for 0xBob bytes32 finalSlot = keccak256(abi.encode(0xBob, base));
 *  finalSlot = the actual storage slot where the value is stored
 *
 *
 *  The value 1000 is stored at finalSlot
 *
 *
 *
 */
