pragma solidity 0.8.17;

import "@zondax/filecoin-solidity/contracts/v0.8/SendAPI.sol";
import {MinerAPI} from "@zondax/filecoin-solidity/contracts/v0.8/MinerAPI.sol";
import {MinerTypes} from "@zondax/filecoin-solidity/contracts/v0.8/types/MinerTypes.sol";
import {BigIntCBOR} from "@zondax/filecoin-solidity/contracts/v0.8/cbor/BigIntCbor.sol";


// a proxy contract for handling SP operate
contract MinerProxy{

    

    function redeem(uint orderID, bool withdrawType) external returns(bool){
        //get profit from current proxy contract 
        return true;
    }

    function getProfit(uint plID,uint orderID) external returns ( bool ){

        // some algorithm for profit calculating
        uint256 profitestimate = address(this).balance * 1 / 10 ; //  
        // userData[msg.sender]. 
        // minePoolMap[userData[msg.sender].poolID].
        payable(msg.sender).transfer(profitestimate);
        return true;

    }//end function
}