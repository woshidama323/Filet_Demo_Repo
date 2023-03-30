// SPDX-License-Identifier: MIT
pragma abicoder v2;
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@zondax/filecoin-solidity/contracts/v0.8/SendAPI.sol";
import {MinerAPI} from "@zondax/filecoin-solidity/contracts/v0.8/MinerAPI.sol";
import {MinerTypes} from "@zondax/filecoin-solidity/contracts/v0.8/types/MinerTypes.sol";
import {BigIntCBOR} from "@zondax/filecoin-solidity/contracts/v0.8/cbor/BigIntCbor.sol";

// import {specific_authenticate_message_params_parse, specific_deal_proposal_cbor_parse} from "./CBORParse.sol";

import "./FiletContractStorage.sol";

contract FiletContract {
    using SafeMath for uint256;
    FiletContractStorage private storageRef;
    //parameters : HFIL token, 
    struct timeCollect {
            uint curDayTime;
            uint userCreateDayTime;
            uint curSubDayTime;
            uint updateDayTime;
    }

    constructor() {
        
        storageRef = FiletContractStorage(msg.sender);
        storageRef.setOwner(msg.sender) ;
    }

    //used for add admin control 
    modifier onlyOwner() { // Modifier
        require(
            msg.sender == storageRef._owner(),
            "Only onwer can call this."
        );
        _;
    }

    //used for add admin control 
    modifier ownerAndAdmin() { // Modifier
        require(
            msg.sender == storageRef._owner() || msg.sender == storageRef._admin(),
            "Only onwer or admin can call this."
        );
        _;
    }

    //lock the contract for safing 
    modifier switchOn() { // Modifier
        require(
            storageRef._switchOn(),
            "switch is off"
        );
        _;
    }
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
        
        storageRef.setAdmin(newAdminUser);
        return true;
    }

    //switch on or off the contract 
    function switchOnContract(bool op) external ownerAndAdmin returns (bool){
        emit SwitchOnContractEvent(op);
        storageRef.setSwitchOn(op);
        return true;
    }

    // transfer current owner to a new owner account
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(storageRef._owner(), newOwner);

        storageRef.setOwner(newOwner);
    }
    
    //===================================user operate ==================================================
    //stake for user

    function stake(uint256 amount,uint poolID) external switchOn returns(bool){
        //todo user need to be checked 

        (
            FiletContractStorage.minePool memory mPool,
            bool isEntity
        ) = storageRef.minePoolMap(poolID);
        
        require(isEntity,"current pool does not exist");
        require(mPool.actionType == 1,"current pool action type mismatch");
        require(mPool.recievePaymentAccount != address(0), "there is no such miner address in the contract" );
        
        // ((minFILAmount / 10**18) * tokenRate / FilRate)* tokenPrecision 
        // uint256 miniTokenAmount = mPool.miniPurchaseAmount.mul(10**mPool.tokenPrecision).mul(mPool.tokenRate).div(mPool.FILRate).div(10**18);
        require(storageRef.calculateMintoken(mPool) <= amount, "input amount must be larger than min amount" );
        // address minerAddr = mPool.recievePaymentAccount;

        uint256 power = storageRef.convertTokenToPower(amount,poolID);
       
        uint orderLength ;//=  storageRef.getLengthOfUserData(msg.sender);
        uint isPremiumLatest  = 0;
        uint arrLen = orderLength - 1;
        FiletContractStorage.userOrder memory userO;

        (userO,orderLength) = storageRef.getUserData(msg.sender,arrLen);

        if (orderLength == 0){
            
            storageRef.setUserPremiumLevelInfo(msg.sender,FiletContractStorage.userPremiumLevelInfoType({
                userAddr:               msg.sender,    
                levelIndex:             isPremiumLatest,
                levelThredholdValue:    mPool.poolThredhold[isPremiumLatest],
                levelServerFee:         mPool.serviceFeePercent[isPremiumLatest]
            }));
        }
        //calculate the server fee level
        uint calcuResult = storageRef.checkisPremium(amount ,mPool.poolThredhold);
        if (isPremiumLatest < calcuResult ){
            isPremiumLatest = calcuResult;

            //record the users level premium info, only update when isPremiumLatest has changed
            storageRef.setUserPremiumLevelInfo(msg.sender,FiletContractStorage.userPremiumLevelInfoType({
                userAddr:               msg.sender,    
                levelIndex:             isPremiumLatest,
                levelThredholdValue:    mPool.poolThredhold[isPremiumLatest],
                levelServerFee:         mPool.serviceFeePercent[isPremiumLatest]
            }));
        }

        // FiletContractStorage.ratioStruct memory ratioInfo;
        userO.ratioInfo.ostakingPrice    = mPool.stakingPrice.mul(mPool.tokenRate).div(mPool.FILRate);
        userO.ratioInfo.oserviceFeePercent = mPool.serviceFeePercent[isPremiumLatest];

        require(mPool.maxMiningPower.canSell >= power ,"the current pool have no enough token to be selled");

        mPool.maxMiningPower.canSell = mPool.maxMiningPower.canSell.sub(power);

        require(mPool.tokenInterface.transferFrom(msg.sender,address(this),amount),"failed to transfer token to contract account for staking");//minerAddress

        mPool.hasSoldOutToken = mPool.hasSoldOutToken.add(amount);

        emit EventUserStaking(
            msg.sender,
            orderLength - 1,
            amount,
            poolID,
            power,
            mPool.tokenAddress, 
            mPool.expireType, 
            mPool.actionType,    
            userO.ratioInfo.oserviceFeePercent
        );
        return true;
    }

    function redeem(uint orderID, bool withdrawType) external returns(bool){

        //calculate the rules
        FiletContractStorage.userOrder memory userO;
        uint orderLength;
        (userO,orderLength) = storageRef.getUserData(msg.sender,orderID);
        require(orderLength > 0,"cannot find this user from contract for redeem");

        (
            FiletContractStorage.minePool memory mPool,
            bool isEntity
        ) = storageRef.minePoolMap(userO.poolID);

        require(userO.user!=address(0),"stakingCon:redeem: cannot find the user order with current order id");
        require(isEntity,"no pool can be found");
        

        require(userO.stopDayTime == 0,"you have redeem already");
        require(mPool.actionType == 1,"only support redeem");
        

        timeCollect memory timeC;
        timeC.curDayTime = storageRef.convertToDayTime(block.timestamp);
        timeC.userCreateDayTime = storageRef.convertToDayTime(userO.createTime);
        //currentTime - createTime
        timeC.curSubDayTime = timeC.curDayTime.sub(timeC.userCreateDayTime);


        if (timeC.curSubDayTime < mPool.expireType){
            mPool.maxMiningPower.canSell = mPool.maxMiningPower.canSell.add(userO.cfltamount);
        }

        userO.cfltamount = 0;

        require(timeC.curSubDayTime >= mPool.lockInterval ,"not allow redeem within frozen days");
        
        require(userO.ratioInfo.admineUpdateTime > 0,"cannot redeem because no fee update");
        timeC.updateDayTime = storageRef.convertToDayTime(userO.ratioInfo.admineUpdateTime);
        timeC.updateDayTime = timeC.updateDayTime.sub(timeC.userCreateDayTime);

        if(timeC.curSubDayTime < mPool.expireType){
            require(timeC.updateDayTime >= mPool.lockInterval.sub(1) ,"not allow redeem because update fee has not come for LOCK days"); 
        }else{
            require(timeC.updateDayTime >= mPool.expireType.sub(1) ,"not allow redeem because update fee has not come for EXP days");    
        }

        uint256 lastForTransfer = 0 ;
        bool isExpire = false;
        uint256 Fee = 0;
        if (timeC.curSubDayTime >= mPool.expireType){
            lastForTransfer = userO.amount;
            userO.stopDayTime = timeC.curDayTime;
            isExpire = true;

        }else{
            //make sure user will not loss any staking money
            if (userO.ratioInfo.oActiveInterest < userO.ratioInfo.oNeedToPayGasFee ){
                emit MarkingFeeChanges(msg.sender,orderID,userO.ratioInfo.oActiveInterest,userO.ratioInfo.oNeedToPayGasFee);
                userO.ratioInfo.oNeedToPayGasFee = userO.ratioInfo.oActiveInterest;
            }
            
            //((gasFIL /10**18 )* tokenRate / FILRate) * 10 ** tokenPrecision 
            uint256 partialCalc = userO.ratioInfo.oNeedToPayGasFee.mul(mPool.tokenRate).mul(10**mPool.tokenPrecision);
            Fee = partialCalc.div(mPool.FILRate).div(10**18) ;
      
            if (userO.amount > Fee ){
                lastForTransfer = userO.amount.sub(Fee);
            }

            userO.stopDayTime = timeC.curDayTime;
        }

        require(lastForTransfer > 0,"not enough for paying for gas diff");
        address forEvent = address(0);
        if (withdrawType ){
            mPool.tokenInterface.transferFrom(mPool.redeemFundAccount,msg.sender,lastForTransfer);
            forEvent = mPool.tokenAddress;
        }else {
            uint256 remainPower =storageRef.convertTokenToPower(userO.amount,userO.poolID) ;
            require(storageRef._fltTokenContract() != address(0),"no flt contract in the system");
            require(IERC20(storageRef._fltTokenContract()).transfer(msg.sender,remainPower),"failed to redeem from contract address");
            forEvent = storageRef._fltTokenContract();
        }

        storageRef.setUserData(msg.sender,FiletContractStorage.userOrder({
                user:               msg.sender,
                amount :            userO.amount,
                status :            userO.status,
                cfltamount :        userO.cfltamount,
                poolID :            userO.poolID,
                createTime :        userO.createTime,
                targetminer :       userO.targetminer ,
                ratioInfo  :        userO.ratioInfo,
                lastProfitEnd :     userO.lastProfitEnd,
                lastProfitPerGiB :  userO.lastProfitPerGiB,
                stopDayTime :       userO.stopDayTime,
                isPremium   :       userO.isPremium
            }),
            orderID
        );

        storageRef.setMinePoolMap(userO.poolID,mPool);

        emit EventRedeem(msg.sender,orderID,Fee,isExpire,forEvent);
        return true;
    }

    function getProfit(uint plID,uint orderID) external returns ( bool ){
        (
            FiletContractStorage.userOrder memory userOr,
            uint orderLength
        ) = storageRef.getUserData(msg.sender,orderID);

        (
            FiletContractStorage.minePool memory mPool,
            bool isEntity
        ) = storageRef.minePoolMap(plID);


        require(orderLength > 0,"cannot find this user from contract for withdraw");
        require(userOr.user!=address(0),"stakingCon:getProfit: cannot find current user with order ID");

        require(isEntity, "pool id does not match with current order");
        require(storageRef._filTokenContract() != address(0),"has not set fil token contract");

        require(userOr.ratioInfo.oActiveInterest > 0, "no TotalInterest for withdrawing");

        require(userOr.ratioInfo.oActiveInterest > userOr.ratioInfo.oHasReceiveInterest, "you have gotten all the interest about this order");

        uint256 interestShouldSend = userOr.ratioInfo.oActiveInterest.sub(userOr.ratioInfo.oHasReceiveInterest);

        require(IERC20(storageRef._filTokenContract()).transferFrom(mPool.redeemFundAccount,msg.sender,interestShouldSend),"failed to withdraw profit for current");
        userOr.ratioInfo.oHasReceiveInterest = userOr.ratioInfo.oActiveInterest;

        emit EventWithDraw( msg.sender,plID,orderID,interestShouldSend);

        return true;

    }//end function

    //===================================admin operate==================================================

    /**
     * @dev event for updating miner pool
    */
    event UpdateMinePoolEvent(uint poolID,address contr,uint256  hasSoldOutToken);

    //add contract to contract and also add pool amount 

    function updateMinePool(
        FiletContractStorage.updateMineInput memory updateParas,
        uint256[] memory poolThredhold,
        uint[] memory serviceFeePercent
    ) external ownerAndAdmin switchOn returns (bool){

        (
            FiletContractStorage.minePool memory mPool,
            bool isEntity
        ) = storageRef.minePoolMap(updateParas.poolID);

        //update the amount of a certain contract
        // if (isEntity){
        //     //an old one
        //     require(storageRef.isContract(updateParas.contr),"not the correct token contract address");
        //     if (updateParas.actionType > 0){
        //         require(updateParas.actionType == 1 || updateParas.actionType == 2,"need to set actionType correctly");
        //         mPool.actionType = updateParas.actionType;
        //     }

        //     if (updateParas.maxMiningPower > 0 ){
        //         mPool.maxMiningPower.canSell = updateParas.maxMiningPower; 
        //     }

        //     if (updateParas.expiration > 0){
        //         mPool.expireType = updateParas.expiration;
        //     }
            
        //     if (updateParas.stakingPrice > 0){
        //         mPool.stakingPrice = updateParas.stakingPrice;
        //     }

        //     if (updateParas.tokenRate > 0 ){
        //         mPool.tokenRate = updateParas.tokenRate;
        //     }

        //     if (updateParas.FILRate > 0 ){
        //         mPool.FILRate = updateParas.FILRate;
        //     }

        //     if (updateParas.tokenPrecision > 0 ){
        //         mPool.tokenPrecision = updateParas.tokenPrecision;
        //     }

        //     if (updateParas.miniPurchaseAmount > 0){
        //         mPool.miniPurchaseAmount = updateParas.miniPurchaseAmount;
        //     }

        //     if (updateParas.hasSoldOutToken > 0){
        //         mPool.hasSoldOutToken = updateParas.hasSoldOutToken;
        //     }

        //     if (updateParas.lockInterval > 0){
        //         mPool.lockInterval = updateParas.lockInterval;
        //     }

        //     if (updateParas.contr != address(0)){
        //         mPool.tokenAddress = updateParas.contr;
        //         mPool.tokenInterface = IERC20(mPool.tokenAddress);
        //     }
            
        //     if (updateParas.redeemCon != address(0)){
        //         mPool.redeemFundAccount = updateParas.redeemCon;
        //     }

        //     if (updateParas.earlyRedeemFundAccount != address(0)){
        //         mPool.earlyRedeemFundAccount = updateParas.earlyRedeemFundAccount;
        //     }
            
        //     if (updateParas.minerAccount != address(0)){
        //         mPool.minerAccount = updateParas.minerAccount;
        //     }            
            
        //     if (updateParas.recievePaymentAccount != address(0)){
        //         mPool.recievePaymentAccount = updateParas.recievePaymentAccount;
        //     }

        //     if (poolThredhold.length > 0){
        //         mPool.poolThredhold = poolThredhold;
        //     }

        //     if (serviceFeePercent.length > 0) {
        //         mPool.serviceFeePercent = serviceFeePercent;
        //     }
        // }else{
        //     //a  new one 
        //     //need to set ratio and maxMiningPower
        //     require(updateParas.maxMiningPower>0,"this pool is new please add maxMiningPower for it");
        //     require(updateParas.contr != address(0),"this pool is new please add token adress for it");
        //     require(updateParas.stakingPrice > 0,"need to set stakingPrice ");
        //     // require(updateParas.serviceFeePercent > 0,"need to set serviceFeePercent ");

        //     require(updateParas.FILRate > 0,"need to set FILRate");
        //     require(updateParas.tokenRate > 0,"need to set tokenRate");
        //     require(updateParas.tokenPrecision > 0,"need to set tokenPrecision");

        //     require(updateParas.actionType == 1 || updateParas.actionType == 2,"need to set actionType correctly");
        //     require(updateParas.miniPurchaseAmount > 0,"need to set miniPurchaseAmount");
        //     require(poolThredhold.length > 0, "need to set levelThredhold for defi");
        //     mPool.poolThredhold = poolThredhold;

        //     require(serviceFeePercent.length > 0, "need to set levelServiceFeePercent for defi");
        //     mPool.serviceFeePercent = serviceFeePercent;

        //     // require(updateParas.lockInterval > 0,"need to set lockInterval");

        //     mPool.maxMiningPower.canSell = updateParas.maxMiningPower;
        //     mPool.stakingPrice = updateParas.stakingPrice; // fil / G 
        //     mPool.FILRate = updateParas.FILRate;
        //     mPool.tokenRate = updateParas.tokenRate;

        //     mPool.tokenAddress = updateParas.contr;
        //     mPool.tokenInterface = IERC20(updateParas.contr);
        //     isEntity = true;
        //     mPool.redeemFundAccount = updateParas.redeemCon;
        //     mPool.earlyRedeemFundAccount = updateParas.earlyRedeemFundAccount;
        //     mPool.expireType = updateParas.expiration;
        //     mPool.minerAccount = updateParas.minerAccount;
        //     mPool.recievePaymentAccount = updateParas.recievePaymentAccount;

        //     mPool.actionType = updateParas.actionType;
        //     mPool.miniPurchaseAmount = updateParas.miniPurchaseAmount;
        //     mPool.lockInterval = updateParas.lockInterval;
        //     mPool.tokenPrecision = updateParas.tokenPrecision;

        // }
        // mPool = updateParas; //todo
        storageRef.setMinePoolMap(updateParas.poolID,mPool);
        emit UpdateMinePoolEvent(updateParas.poolID,updateParas.contr,updateParas.hasSoldOutToken);
        return true;

    }

    /**
     * @dev event for updating user order fee
    */
    event UpdateOrderFeeEvent(
        address userAddress,
        uint    orderID,
        uint    updateTime,
        uint256 activeInterest,
        uint256 FrozenInterest,
        uint256 needToPayGasFee
    );



    function updateOrderFee(FiletContractStorage.updateUserOrderType[] memory updateOrders) external ownerAndAdmin switchOn returns (bool){
        require(updateOrders.length > 0, "please input the right data for updateOrderFee");

        
        for (uint i = 0 ;i < updateOrders.length;i++){
            
            // uint length = storageRef.getLengthOfUserData(updateOrders[i].userAddress);//userData(,updateOrders[i].orderID)
            FiletContractStorage.userOrder memory userOr;
            uint length;
            (userOr,length) = storageRef.getUserData(updateOrders[i].userAddress,updateOrders[i].orderID);
            if (length == 0){
                continue;
            }

            // (
            //     address user,           
            //     uint256 amount,           
            //     uint    poolID,             
            //     bool    status,            
            //     uint256 cfltamount,        
            //     uint256 createTime,         
            //     address targetminer,       
            //     FiletContractStorage.ratioStruct memory ratioInfo,
            //     uint    lastProfitEnd,     
            //     uint256 lastProfitPerGiB,  
            //     uint    stopDayTime,       
            //     uint  isPremium
            // ) = storageRef.userData(updateOrders[i].userAddress,updateOrders[i].orderID);

            (
                FiletContractStorage.minePool memory mPool,
                bool isEntity
            ) = storageRef.minePoolMap(userOr.poolID);
            //say did not expired
            if (userOr.stopDayTime == 0 ){
                if (userOr.user == address(0)){
                    continue;
                }
       
                uint    cDayTime    = storageRef.convertToDayTime(userOr.createTime);
                // uint256 poolIDForex = poolID;
                if (updateOrders[i].updateTime > 0 && storageRef.convertToDayTime(updateOrders[i].updateTime) < cDayTime.add(mPool.expireType).sub(1)){
                    userOr.ratioInfo.admineUpdateTime = updateOrders[i].updateTime;
                    userOr.ratioInfo.oActiveInterest = updateOrders[i].activeInterest;
                    userOr.ratioInfo.oFrozenInterest = updateOrders[i].FrozenInterest;
                    userOr.ratioInfo.oNeedToPayGasFee = updateOrders[i].needToPayGasFee;
                    // storageRef.setUserData(updateOrders[i].userAddress,updateOrders[i].orderID,userOr);
                    emit UpdateOrderFeeEvent(updateOrders[i].userAddress,updateOrders[i].orderID,updateOrders[i].updateTime,updateOrders[i].activeInterest,updateOrders[i].FrozenInterest,updateOrders[i].needToPayGasFee);
                }
                else if (storageRef.convertToDayTime(updateOrders[i].updateTime) >= cDayTime.add(mPool.expireType).sub(1)){

                    mPool.maxMiningPower.canSell = mPool.maxMiningPower.canSell.add(userOr.cfltamount);
                    userOr.cfltamount = 0;
                    storageRef.setMinePoolMap(userOr.poolID,mPool);   //mPool //storageRef.setMinePoolMap(updateParas.poolID,mPool);
                }
                storageRef.setUserData(updateOrders[i].userAddress,userOr,updateOrders[i].orderID);
            }
        }

        return true;
    }

    //add flt token contract;
    function addFLTTokenContract(address fltToken) external ownerAndAdmin switchOn returns (bool){
        require(fltToken != address(0),"stakingCon:addFLTTokenContract: fltToken address is zero");

        storageRef.setFltTokenContract(fltToken);
        emit AddFLTTokenContractEvent(fltToken);
        return true;
    }

    //add fil token contract for profit;
    function addFILTokenContract(address filTokenCon) external ownerAndAdmin switchOn returns (bool){
        require(filTokenCon != address(0),"stakingCon:addFILTokenContract: filToken address is zero");
        storageRef.setFilTokenContract(filTokenCon);


        emit AddFILTokenContractEvent(filTokenCon);
        return true;
    }

    event MinerRetrieveTokenEvent(
        address user,
        uint    poolID,
        uint256 amount
    );
    // //miner get tokens from certain pool with flt 
    function minerRetrieveToken(uint poolID,uint256 amount) external switchOn returns (bool){


        (
            FiletContractStorage.minePool memory mPool,
            bool isEntity
        ) = storageRef.minePoolMap(poolID);
        require(isEntity,"current pool does not exist");

        require(msg.sender == mPool.minerAccount,"user has not registered on the contract");

        require(mPool.actionType == 1,"only staking pool can retrieval token ");

        require(amount <= mPool.hasSoldOutToken,"not enough token to be back for miner");
        mPool.hasSoldOutToken = mPool.hasSoldOutToken.sub(amount);

        uint256 getPower = storageRef.convertTokenToPower(amount,poolID);
        require(IERC20(storageRef._fltTokenContract()).transferFrom(msg.sender,address(this),getPower),"failed to transfer file from user to contract");
        require(mPool.tokenInterface.transfer(msg.sender,amount),"failed to transfer flt from user to contract");
        emit MinerRetrieveTokenEvent(msg.sender,poolID,amount);
        return true;        
    }

    //miner get tokens from certain pool with flt 
    // function minerRetrieveFILE(uint poolID,uint256 amount) public switchOn returns (bool){

    //     require(storageRef.minePoolMap[poolID].isEntity,"current pool does not exist");

    //     require(msg.sender == storageRef.minePoolMap[poolID].mPool.minerAccount,"user has not registered on the contract");

    //     require(storageRef.minePoolMap[poolID].mPool.actionType == 1,"only staking pool can retrieval token ");

    //     require(storageRef.minePoolMap[poolID].mPool.maxMiningPower.canSell >= amount,"not enough file to retrieve");

    //     storageRef.minePoolMap[poolID].mPool.maxMiningPower.canSell = storageRef.minePoolMap[poolID].mPool.maxMiningPower.canSell.sub(amount);

    //     require(IERC20(FiletContractStorage._fltTokenContract).transfer(msg.sender,amount),"failed to transfer FILE from contract");

    //     return true;

    // }

    //===================================tool function==================================================

}