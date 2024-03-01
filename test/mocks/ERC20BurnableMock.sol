// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

import {IERC20MintableBurnable} from "../../src/interfaces/IERC20MintableBurnable.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract ERC20BurnableMock is ERC20, ERC20Burnable, IERC20MintableBurnable {
    constructor(
        string memory name_,
        string memory symbol_
    ) ERC20(name_, symbol_) {}

    function mint(address account, uint256 amount) external {
        _mint(account, amount);
    }

    function burn(
        uint256 amount
    ) public override(ERC20Burnable, IERC20MintableBurnable) {
        ERC20Burnable.burn(amount);
    }

    function burnFrom(
        address account,
        uint256 amount
    ) public override(ERC20Burnable, IERC20MintableBurnable) {
        ERC20Burnable.burnFrom(account, amount);
    }
}
