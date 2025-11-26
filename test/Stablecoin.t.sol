// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/Stablecoin.sol";

contract StableCoinTest is Test {
    StableCoin public stableCoinContract;
    address public raju;
    uint256 public rajyPraivateKey;

    function setUp() public {
        stableCoinContract = new StableCoin("Chinna", "CHINNA", 1 ether);

        (raju, rajyPraivateKey) = makeAddrAndKey("raju");
    }

    function testCheckBalance() public view {
        uint256 balabceOfChinna = stableCoinContract.balanceOf(address(this));

        console.log("The balance of Chinna the owner is:", balabceOfChinna);
    }
}
