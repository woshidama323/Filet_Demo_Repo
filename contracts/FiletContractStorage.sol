// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@zondax/filecoin-solidity/contracts/v0.8/SendAPI.sol";
import {MinerAPI} from "@zondax/filecoin-solidity/contracts/v0.8/MinerAPI.sol";
import {MinerTypes} from "@zondax/filecoin-solidity/contracts/v0.8/types/MinerTypes.sol";
import {BigIntCBOR} from "@zondax/filecoin-solidity/contracts/v0.8/cbor/BigIntCbor.sol";

// import {specific_authenticate_message_params_parse, specific_deal_proposal_cbor_parse} from "./CBORParse.sol";



contract FiletContractStorage {
    using SafeMath for uint256;
    uint constant public BigEnough = 2**20 - 1;
    //一天的秒数
    uint public constant secondsForOneDay = 86400;//86400;

    //时区调整
    uint public constant timeZoneDiff = 28800;

    //admin control
    //contract owner address
    address public _owner;

    function setOwner(address newOwner) public{

        _owner = newOwner;
    
    }

    address public _admin;
    function setAdmin(address newAdmin) public{

        _admin = newAdmin;
    
    }

    //contract switch
    bool public _switchOn = false;
    function setSwitchOn(bool op) public{

        _switchOn = op;
    
    }

    //IERC FLT token Obj
    address public _fltTokenContract;

    function setFltTokenContract(address newFltTokenContract) public{

        _fltTokenContract = newFltTokenContract;
    
    }

    //fltTokenContract
    address public _filTokenContract;

    function setFilTokenContract(address newFilTokenContract) public{

        _filTokenContract = newFilTokenContract;
    
    }

    struct maxMiningPowerType{
        uint256 canSell;
        uint256 canNotSell;
    }
    //mine pool info struct 
    struct minePool{
        IERC20      tokenInterface;             
        address     tokenAddress;               
        uint        expireType;                 
        uint        actionType;         

        maxMiningPowerType      maxMiningPower;
        address     earlyRedeemFundAccount;       
        address     redeemFundAccount;        
        address     minerAccount;
        uint256     stakingPrice;      
        uint256     tokenRate;          
        uint256     FILRate;       
        uint        tokenPrecision;

        address     recievePaymentAccount;
        uint256     miniPurchaseAmount;
        uint256     hasSoldOutToken;
        uint        lockInterval;
        uint256[]   poolThredhold;
        uint[]    serviceFeePercent;
    }   

    struct minePoolWrapper{
        minePool mPool;
        bool    isEntity;
    }

    //minepool map
    mapping(uint => minePoolWrapper) public minePoolMap;
    function setMinePoolMap(uint poolID, minePool memory mPool) public {
        minePoolMap[poolID].mPool = mPool;
        minePoolMap[poolID].isEntity = true;
    }

    mapping(address => userOrder[]) public userData;

    function getLengthOfUserData(address userAddr) public returns(uint){
        return userData[userAddr].length;
    }

    function setUserData(address user, userOrder memory userO, uint orderID ) public {
        
        //how to check if the user's order exist? please give me the codes

        //it's for push order
        if (orderID == BigEnough){
            userData[user].push(userO);
        }else{
            if (userData[user].length < orderID) {
                require(false, "orderID is too big");
            }else {
                userData[user][orderID] = userO;
            }
        }
    }

    function getUserData(address user, uint orderID ) public returns( userOrder memory, uint){

        userOrder memory ret = userData[user][orderID];
        return  (ret,getLengthOfUserData(user));
    }



    address[] public minerPool;
    
    /** 
    * struct for hold the ratio info
    */
    struct ratioStruct {
        uint256 ostakingPrice;     
        uint  oserviceFeePercent;  
        uint256 oActiveInterest;

        uint256 oFrozenInterest;
        uint256 oHasReceiveInterest;
        uint256 oNeedToPayGasFee;   
        uint256 admineUpdateTime;
    }

    /**
     * @dev user order for mine
    */
    struct userOrder {
        address user;              
        uint256 amount;           
        uint    poolID;             
        bool    status;            
        uint256 cfltamount;        
        uint256 createTime;         
        address targetminer;       
        ratioStruct ratioInfo;
        uint    lastProfitEnd;     
        uint256 lastProfitPerGiB;  
        uint    stopDayTime;       
        uint  isPremium;      

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

    // set a set function for userPremiumLevelInfo
    function setUserPremiumLevelInfo(address user,userPremiumLevelInfoType memory preInfo) public {
        userPremiumLevelInfo[user] = preInfo;

    }


    //updatefee 
    struct updateUserOrderType {
        address userAddress;
        uint    orderID;
        uint    updateTime;
        uint256 activeInterest;
        uint256 FrozenInterest;
        uint256 needToPayGasFee;
    }

    //check if address is contract
    function isContract(address _addr) view public  returns (bool){
        uint32 size;
        assembly {
            size := extcodesize(_addr)
        }
        return (size > 0);
    }

    //convert current time to day time
    function convertToDayTime(uint forConvertTime) public view returns (uint){
        return forConvertTime.add(timeZoneDiff).div(secondsForOneDay);
    }

    //check if it is Premium

    function checkisPremium(uint256 amount,uint256[] memory levelThredhold) public pure returns (uint){
        
        uint isPrem = 0;
        for (uint i = levelThredhold.length.sub(1);i >= 0 ; i--){
            // powerToToken = levelThredhold[i].mul(stakingPrice).mul(tokenToFILRate).div(10**18).div(10**18);
            if (amount >= levelThredhold[i]){
                isPrem = i;
                break;
            }
        }
        return isPrem;
    }

    //convert token to power
   
    function convertTokenToPower(uint256 amount, uint poolID) public view returns (uint256){
        // (( (tokenamount / (10**precision)) / (tokenRate / FILRate) ) / (stakingPrice / 10**18)) * (10**18)
        return amount.mul(10**18).mul(10**18).mul(minePoolMap[poolID].mPool.FILRate).div(minePoolMap[poolID].mPool.tokenRate).div(minePoolMap[poolID].mPool.stakingPrice).div(10**minePoolMap[poolID].mPool.tokenPrecision);
    }

    //
    struct updateMineInput{
        uint        poolID;            
        address     contr;      
        address     redeemCon;             
        address     earlyRedeemFundAccount;    
        address     minerAccount;
        address     recievePaymentAccount;    
        uint        expiration;             

        uint256     maxMiningPower;         
        uint256     stakingPrice;            
 
        uint256     tokenRate;
        uint256     FILRate;
        uint        tokenPrecision;

        uint        actionType;
        uint256     miniPurchaseAmount;
        uint256     hasSoldOutToken;
        uint        lockInterval;
    }

    function calculateMintoken( minePool memory mPool) public returns(uint256){

        return mPool.miniPurchaseAmount.mul(10**mPool.tokenPrecision).mul(mPool.tokenRate).div(mPool.FILRate).div(10**18);
    }

}