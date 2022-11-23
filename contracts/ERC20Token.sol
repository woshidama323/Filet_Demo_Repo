//SPDX-License-Identifier: Unlicense
pragma solidity  ^0.8.0;

// import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract ERC20Token is ERC20 {

    address private _owner ;

    constructor() ERC20("FILToken","FIL"){


        _mint(msg.sender,uint(100000000000000));

    }
}