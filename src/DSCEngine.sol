// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

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
    // ======================== Storage Slots ========================

    mapping(address token => address oracleFeedAddress)
        private oraclePriceFeeds;

    // @notice this is for traking amount for each user and for each users token address
    mapping(address user => mapping(address token => uint256 amount))
        private collateralDeposited; // collateral user deposited

    mapping(address user => uint256 dscAmountMinted) private dscUserAmount; // stable coins minted per user

    StableCoin private immutable stablCoinContract;

    // ======================== Errors ========================

    error DSCEngine_AmountShouldNotBeZero();
    error DSCEngine_InvalidCollateralAddress();
    error DSCEngine_ShouldProvideProperAddress();
    error DSCEngine_ERC20TransferFailed();

    // ======================== Modifiers ========================

    modifier _checkInputAmount(uint256 amount) {
        require(amount > 0, DSCEngine_AmountShouldNotBeZero());
        _;
    }

    modifier _checkCollatralTokenAddress(address collatralAdress) {
        address oracleFeed = oraclePriceFeeds[collatralAdress];

        require(oracleFeed == address(0), DSCEngine_InvalidCollateralAddress());
        _;
    }

    // ======================== Constructor ========================

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
    }

    // ======================== Contract Logic ========================

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

        // Updating the Storage
        collateralDeposited[msg.sender][tokenCollateralAddress] += amount;

        // Transfering ERC20 tokens to this contract from user
        // @notic Patric used transferFrom, but why ??
        require(
            ercTokenAddress.transfer(address(this), amount),
            DSCEngine_ERC20TransferFailed()
        );
    }

    function mintDSC(
        uint256 collateralAmount,
        address to,
        address stableCoinAddress,
        address oracleFeedPrice,
        uint256 amountDSC
    ) public _checkInputAmount(collateralAmount) _checkInputAmount(amountDSC) {
        // There will be a threshold for every collateralAmount
        // we need to check the price of collaterla using Chainlink Oracle
        // based on price and threshold of minting we will mint the stable coins
        // we will check the user req stable coin amount with our result

        dscUserAmount[msg.sender] += amountDSC;
    }

    /**
     * This function will be used of calculating the helth factor of a loan using oracle price feed
     *
     * */
    function helthFactor() public {}
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
