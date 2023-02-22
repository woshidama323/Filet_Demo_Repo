// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@zondax/filecoin-solidity/contracts/v0.8/SendAPI.sol";
import {MinerAPI} from "@zondax/filecoin-solidity/contracts/v0.8/MinerAPI.sol";
import {MinerTypes} from "@zondax/filecoin-solidity/contracts/v0.8/types/MinerTypes.sol";
import {BigIntCBOR} from "@zondax/filecoin-solidity/contracts/v0.8/cbor/BigIntCbor.sol";

// import {specific_authenticate_message_params_parse, specific_deal_proposal_cbor_parse} from "./CBORParse.sol";


import "./ErrorReporter.sol";


contract StakingCon is StakingErrorReporter{

    //Global Constant
    address _MinerActor;
    uint256 LimitAmount = 1e16 ;

    using SafeMath for uint256;
    //admin control
    //contract owner address
    address private _owner;
    address private _admin;

    //contract switch
    bool private _switchOn = false;

    //IERC FLT token Obj
    address public _fltTokenContract;

    //fltTokenContract
    address public _filTokenContract;

    //mine pool info struct 
    struct minePool{    
       address minerID;
       uint256 powerRate;
       uint sectorType;
       uint    scores;
    }   
    //minepool map
    mapping(uint => minePool) public minePoolMap ;

    mapping(address => userOrder[]) public userData;

    address[] public minerPool;
    

    struct MinerPool{
        address miner;
        uint256 Power; 
        uint256 initBalace;
    }

    /**
     * @dev user order for mine
    */
    struct userOrder {
        address user;              
        uint    amount;           
        uint    poolID;             
        bool    status;            
        uint256 cfltamount;        
        uint256 createTime;         
        address targetminer;
    }

    /**
        add map for recording the user's vip level
     */
    struct userPremiumLevelInfoType {
        address userAddr;
        uint  levelIndex;
        uint256 levelThredholdValue;
        uint  levelServerFee;
    }
    mapping(address => userPremiumLevelInfoType) public userPremiumLevelInfo;

    //event
    event OwnershipTransferred(
        address     owner,       
        address     newOwner   
    );

    /**
     * @dev event for output some certain info about user order
    */

    //minePool mPool
    event EventUserStaking(
        address     user,
        uint        orderID,
        uint256     amount,
        uint        poolID,
        uint256     cfltamount,
        address     tokenAddress,        
        uint        expireType,    
        uint        actionType,          
        uint        serviceFeePercent   
    );

    /**
     * @dev event for redeem operating when expiring
    */
    event EventRedeem(address user,uint orderID,uint256 fee,bool isExpire,address mPool);

    /**
     * @dev event for withdraw operating
    */
    event EventWithDraw(address user,uint poolID,uint orderID,uint256 profitAmount);

    //parameters : HFIL token, 
    constructor(address minerid) {
        _owner = msg.sender;   
        _MinerActor =  minerid;
    }

    //used for add admin control 
    modifier onlyOwner() { // Modifier
        require(
            msg.sender == _owner,
            "Only onwer can call this."
        );
        _;
    }

    //used for add admin control 
    modifier ownerAndAdmin() { // Modifier
        require(
            msg.sender == _owner || msg.sender == _admin,
            "Only onwer or admin can call this."
        );
        _;
    }

    //lock the contract for safing 
    modifier switchOn() { // Modifier
        require(
            _switchOn,
            "switch is off"
        );
        _;
    }

    /**
     * @dev event for setting a new admin account
    */
    event SetAdminEvent(address newAdminUser);

    /**
     * @dev event for changing switch state
    */
    event SwitchOnContractEvent(bool operate);

    /**
     * @dev event for adding FILE token contract address
    */
    event AddFLTTokenContractEvent(address fltToken);

    /**
     * @dev event for adding FIL token contract address
    */
    event AddFILTokenContractEvent(address filTokenCon);

    /**
     * @dev event for mark fee changes
    */
    event MarkingFeeChanges(address user,uint orderID,uint256 activeInterest, uint256 fee);

    //owner set a admin permission
    function setAdmin(address newAdminUser) external onlyOwner returns (bool){
        require(newAdminUser != address(0), "StakingCon:setAdmin: new admin user is the zero address");
        emit SetAdminEvent(newAdminUser);
        _admin = newAdminUser;
        return true;
    }

    //switch on or off the contract 
    function switchOnContract(bool op) external ownerAndAdmin returns (bool){
        emit SwitchOnContractEvent(op);
        _switchOn = op;
        return true;
    }

    // transfer current owner to a new owner account
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
    
    //===================================user operate ==================================================
    //stake for user

    function stake(uint256 amount,uint poolID) external payable returns(bool){

        require(msg.value >= 100000, "should staking larger than 100000");
        userData[msg.sender].push(
            userOrder({
                user:               msg.sender,
                amount :            msg.value,
                status :            false,
                cfltamount :        1000000,
                poolID :            poolID,
                createTime :        block.timestamp,
                targetminer :       address(this)
            })
        );
        return true;
    }

    function redeem(uint orderID, bool withdrawType) external returns(bool){
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

    //===================================miner operate ==================================================
    function MinerRegister(MinerPool memory minerInfo) public returns (bool){
        //1.create a smart contract from current 
        //2.change owner address Q: SP will concern the safe of contract ?

        MinerAPI.changeOwnerAddress(toBytes(minerInfo.miner),abi.encodePacked(address(this)));

        MinerTypes.ChangeBeneficiaryParams memory params;
        params.new_beneficiary = abi.encodePacked(address(this));
        params.new_quota.val = abi.encodePacked(address(this).balance);
        // params.new_expiration = uint64(end - block.timestamp);
        MinerAPI.changeBeneficiary(toBytes(minerInfo.miner), params);

        MinerTypes.GetOwnerReturn memory getOwnerReturnValue = MinerAPI.getOwner(toBytes(minerInfo.miner));
        address checkOwner = abi.decode(
            getOwnerReturnValue.owner, 
            (address)
        );

        require(checkOwner != address(this),"miner owner is not correct");

        MinerTypes.GetBeneficiaryReturn memory getBeneficiaryReturnValue = MinerAPI.getBeneficiary(toBytes(minerInfo.miner));
        address checkBeneficiary = abi.decode(getBeneficiaryReturnValue.active.beneficiary,(address));
        require(checkBeneficiary != address(this),"beneficiary is not correct");

        return true;
    }


    //stake function 
    //1. user transfer FIL to current staking contract
    //2. contract transfer FIL to Miner Actor
    //3. Miner actor need to change onwer address with staking contract 
    //4. owner address could be changed by DAO  
    function stake(uint poolid,address target) public payable returns (bool){
        // SendAPI.send(toBytes(target), amount);
        require(LimitAmount > msg.value, "not meet min condition");

        userData[msg.sender].push(userOrder(
            {   user:msg.sender,
                amount:msg.value,
                poolID:1,
                status:true,
                cfltamount:0,
                createTime:0,
                targetminer: target
            })
        );

        return true;
    }

    //as there is no method for transferring user's FIL to miner Proxy directly, Here, we need to change this step with two seperate operating
    function transferFILToMinerProxy(uint256 amount) public {
        // address(this).transfer();
        require(address(this).balance >= amount,"no enough fil could be transfer to miner proxy");
        SendAPI.send(toBytes(_MinerActor), amount);
    }

    //@dev Convert address to bytes //from https://github.com/kazumal/Filecoin-Lending-Pool
    function toBytes(address a) public pure returns (bytes memory) { 
        return abi.encodePacked(a);
    }

    //@dev Convert Bytes to address //from https://github.com/kazumal/Filecoin-Lending-Pool
    function bytesToAddress(  
        bytes memory _bys
    ) private pure returns (address addr) {
        assembly {
            addr := mload(add(_bys, 20))
        }
    }
}