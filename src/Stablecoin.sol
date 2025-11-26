// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title Decentralized Stable Coin Palre imetation working model
 * @author Chinna 🕊️
 * @notice This protocol just demonstrates the working model of the stable coin
 */
contract StableCoin is ERC20, Ownable, ERC20Burnable {
    /**
     * - Mint tokens
     * - Burn Tokens
     * - Transfer Tokens
     * - Allowance
     * - TransferFrom
     * - Using EIP 712 using Openzeppline for the gas less transaction - This is imp for in order to understand hands on
     *
     */

    error DecentralizedStableCoin_MustBeMoreThanZero();
    error DecentralizedStableCoin_NotEnoughAmountToBurn();
    error DecentralizedStableCoin_NotZeroAddress();
    error DecentralizedStableCoin_AmountShouldGreaterThanZero();

    constructor(
        string memory name,
        string memory symbol,
        uint256 initialSupply
    ) ERC20(name, symbol) Ownable(msg.sender) {
        // Miniting the initial supply to the deployer of this contract
        _mint(msg.sender, initialSupply);
    }

    function burnTokens(uint256 amount) public {
        uint256 balanceUser = balanceOf(msg.sender);

        require(balanceUser > 0, DecentralizedStableCoin_MustBeMoreThanZero());

        require(
            balanceUser >= amount,
            DecentralizedStableCoin_NotEnoughAmountToBurn()
        );

        super.burn(amount);
    }

    function minTokens(address to, uint256 amount) public onlyOwner {
        require(to != address(0), DecentralizedStableCoin_NotZeroAddress());
        require(
            amount > 0,
            DecentralizedStableCoin_AmountShouldGreaterThanZero()
        );

        _mint(to, amount);
    }

    /**
     *
     * I would like to add
     *     - allowance
     *     - transferFrom
     *     - gas_less trx using EIP 712 using openZeplline Contracts
     */


    

}
