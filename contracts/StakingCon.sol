// SPDX-License-Identifier: MIT
pragma solidity 0.8.14;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import {MinerAPI} from "./MinerAPI.sol";
import {CommonTypes} from "./types/CommonTypes.sol";
import {MinerTypes} from "./types/MinerTypes.sol";

// import {specific_authenticate_message_params_parse, specific_deal_proposal_cbor_parse} from "./CBORParse.sol";


import "./ErrorReporter.sol";


contract StakingCon is StakingErrorReporter{

    //minerpool minerApiAddress

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
    
    /** 
    * struct for hold the ratio info
    */
    // struct ratioStruct {
    //     uint256 ostakingPrice;     
    //     uint  oserviceFeePercent;  
    //     uint256 oActiveInterest;

    //     uint256 oFrozenInterest;
    //     uint256 oHasReceiveInterest;
    //     uint256 oNeedToPayGasFee;   
    //     uint256 admineUpdateTime;
    // }

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
    constructor() {
        _owner = msg.sender;
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
        // payable(msg.sender).transfer(100000);
        // transferFrom

        return true;
    }

    function redeem(uint orderID, bool withdrawType) external returns(bool){
        return true;
    }

    function getProfit(uint plID,uint orderID) external returns ( bool ){

        // some algorithm for profit calculating
        //1. 获取当前fil余额 （主要来自miner的收益）
        //2. 获取用户占比
        //3. 显示可以提取的收益
        uint256 profitestimate = address(this).balance * 1 / 10 ; //  
        // userData[msg.sender]. 
        // minePoolMap[userData[msg.sender].poolID].
        payable(msg.sender).transfer(profitestimate);
        return true;

    }//end function

    //===================================miner operate ==================================================
    function minerregister(address mineraddress, uint poolid) external returns(bool){
        //need use miner owner to operate
        MinerAPI minerApiInstance = MinerAPI(mineraddress);

        // string memory addr = "t01113";

        // // need to set current address as owner
        // minerApiInstance.mock_set_owner(addr);

        
        //set actor as his beneficiary
        MinerTypes.ChangeBeneficiaryParams memory params;
        params.new_beneficiary = "t03311";
        minerApiInstance.change_beneficiary(params);

        minePoolMap[poolid] = minePool({
            minerID: mineraddress,
            powerRate:1000 * 1 ,
            sectorType: 32  ,
            scores:90
        });

        return true;
    }
}