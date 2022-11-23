// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./ErrorReporter.sol";


contract StakingCon is StakingErrorReporter{
    using SafeMath for uint256;

    //lendhub address
    address private _lendhubAddress;

    //一天的秒数
    uint private constant secondsForOneDay = 86400;//86400;

    //时区调整
    uint private constant timeZoneDiff = 28800;

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
        address     profitFundAccount;     
        address     minerAccount;
        uint256     stakingPrice;      
        uint256     tokenRate;          
        uint256     FILRate;       
        uint        tokenPrecision;

        address     recievePaymentAccount;
        uint256     miniPurchaseAmount;
        uint256     maxPurchaseAmount;
        uint256     hasSoldOutToken;
        uint        lockInterval;
        uint256[]   poolThredhold;
        uint[]      serviceFeePercent;
        uint        lendhubExtraRatio; // 102
    }   

    struct minePoolWrapper{
        minePool mPool;
        bool    isEntity;
    }

    //minepool map
    mapping(uint => minePoolWrapper) public minePoolMap ;

    mapping(address => userOrder[]) public userData;

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

    function stake(uint256 amount,uint poolID) external switchOn returns(bool){
        //todo user need to be checked 

        
        // require(minePoolMap[poolID].isEntity,"current pool does not exist");
        // require(minePoolMap[poolID].mPool.actionType == 1,"current pool action type mismatch");

        // minePool memory localPool = minePoolMap[poolID].mPool;

        // require(localPool.recievePaymentAccount != address(0), "there is no such miner address in the contract" );
        
        // // ((minFILAmount / 10**18) * tokenRate / FilRate)* tokenPrecision 
        // uint256 miniTokenAmount = localPool.miniPurchaseAmount.mul(10**minePoolMap[poolID].mPool.tokenPrecision).mul(localPool.tokenRate).div(localPool.FILRate).div(10**18);
        // uint256 maxTokenAmount = localPool.maxPurchaseAmount.mul(10**minePoolMap[poolID].mPool.tokenPrecision).mul(localPool.tokenRate).div(localPool.FILRate).div(10**18);
        // require(miniTokenAmount <= amount , "input amount must be larger than min amount" );
        // require(amount <= maxTokenAmount, "input amount must be smaller than max amount" );
        // address minerAddr = localPool.recievePaymentAccount;

        // uint256 power = convertTokenToPower(amount,poolID);
       
        // uint isPremiumLatest  = 0;
        // if (userData[msg.sender].length > 0){
        //     isPremiumLatest = userData[msg.sender][userData[msg.sender].length - 1].isPremium;
        // }else{
        //     //if current use is a new one ,just init a level info 
        //     userPremiumLevelInfo[msg.sender] = userPremiumLevelInfoType({
        //         userAddr:               msg.sender,    
        //         levelIndex:             isPremiumLatest,
        //         levelThredholdValue:    localPool.poolThredhold[isPremiumLatest],
        //         levelServerFee:         localPool.serviceFeePercent[isPremiumLatest]
        //     });
        // }
        // //calculate the server fee level
        // uint calcuResult = checkisPremium(amount ,minePoolMap[poolID].mPool.poolThredhold);
        // if (isPremiumLatest < calcuResult ){
        //     isPremiumLatest = calcuResult;

        //     //record the users level premium info, only update when isPremiumLatest has changed
            
        //     userPremiumLevelInfo[msg.sender] = userPremiumLevelInfoType({
        //         userAddr:               msg.sender,    
        //         levelIndex:             isPremiumLatest,
        //         levelThredholdValue:    localPool.poolThredhold[isPremiumLatest],
        //         levelServerFee:         localPool.serviceFeePercent[isPremiumLatest]
        //     });
        // }

        // ratioStruct memory ratioInfo;
        // ratioInfo.ostakingPrice    = localPool.stakingPrice.mul(localPool.tokenRate).div(localPool.FILRate);
        // ratioInfo.oserviceFeePercent = localPool.serviceFeePercent[isPremiumLatest];

        // userData[msg.sender].push(
        //     userOrder({
        //         user:               msg.sender,
        //         amount :            amount,
        //         status :            false,
        //         cfltamount :        power,
        //         poolID :            poolID,
        //         createTime :        block.timestamp,
        //         targetminer :       minerAddr ,
        //         ratioInfo  :        ratioInfo,
        //         lastProfitEnd :     0,
        //         lastProfitPerGiB :  0,
        //         stopDayTime :       0,
        //         isPremium   :       isPremiumLatest
        //     })
        // );

        // require(minePoolMap[poolID].mPool.maxMiningPower.canSell >= power ,"the current pool have no enough token to be selled");

        // minePoolMap[poolID].mPool.maxMiningPower.canSell = minePoolMap[poolID].mPool.maxMiningPower.canSell.sub(power);

        // require(minePoolMap[poolID].mPool.tokenInterface.transferFrom(msg.sender,address(this),amount),"failed to transfer token to contract account for staking");//minerAddress

        // minePoolMap[poolID].mPool.hasSoldOutToken = minePoolMap[poolID].mPool.hasSoldOutToken.add(amount);

        // emit EventUserStaking(
        //     msg.sender,
        //     userData[msg.sender].length - 1,
        //     amount,
        //     poolID,
        //     power,
        //     localPool.tokenAddress, 
        //     localPool.expireType, 
        //     localPool.actionType,    
        //     ratioInfo.oserviceFeePercent
        // );
        return true;
    }

    // function redeem(uint orderID, bool withdrawType) external returns(bool){

    //     //order need exist
    //     require(userData[msg.sender].length > 0,"cannot find this user from contract for redeem");
    //     //order user need exist
    //     require(userData[msg.sender][orderID].user!=address(0),"stakingCon:redeem: cannot find the user order with current order id");
    //     userOrder memory uOrder = userData[msg.sender][orderID];

    //     //pool the order store need exist
    //     require(minePoolMap[uOrder.poolID].isEntity,"no pool can be found");
        
    //     //
    //     uint curDayTime = convertToDayTime(block.timestamp);
    //     uint userCreateDayTime = convertToDayTime(uOrder.createTime);
    //     //currentTime - createTime
    //     uint curSubDayTime = curDayTime.sub(userCreateDayTime);

    //     require(userData[msg.sender][orderID].stopDayTime == 0,"you have redeem already");
    //     require(minePoolMap[uOrder.poolID].mPool.actionType == 1,"only support redeem");
        
    //     if (curSubDayTime < minePoolMap[uOrder.poolID].mPool.expireType){
    //         minePoolMap[uOrder.poolID].mPool.maxMiningPower.canSell = minePoolMap[uOrder.poolID].mPool.maxMiningPower.canSell.add(uOrder.cfltamount);
    //     }

    //     userData[msg.sender][orderID].cfltamount = 0;
    //     userData[msg.sender][orderID].stopDayTime = curDayTime;

    //     //here handle special pool for redeeming
    //     //fix the pool id  to 99(ht) and 999(bsc) as current return version 
    //     if (uOrder.poolID == 99 || uOrder.poolID == 999){
    //         require(maintenanceFuncRedeem(uOrder.poolID,userData[msg.sender][orderID].amount) ,"failed to redeem for user");
    //         emit EventRedeem(msg.sender,orderID,0,true,minePoolMap[uOrder.poolID].mPool.tokenAddress);
    //         return true;
    //     }
        
    //     //if file pool no any check
    //     if (minePoolMap[uOrder.poolID].mPool.tokenAddress == _fltTokenContract && _fltTokenContract != address(0)){

    //         require(IERC20(_fltTokenContract).transfer(msg.sender,uOrder.amount),"failed to redeem from file pool in contract");
    //         // require(IERC20(_fltTokenContract).transferFrom(minePoolMap[uOrder.poolID].mPool.redeemFundAccount,msg.sender,uOrder.amount),"failed to redeem from file pool in contract");
    //         emit EventRedeem(msg.sender,orderID,0,false,_fltTokenContract);
    //         return true;
    //     }

    //     require(curSubDayTime >= minePoolMap[uOrder.poolID].mPool.lockInterval ,"not allow redeem within frozen days");
        
    //     require(uOrder.ratioInfo.admineUpdateTime > 0,"cannot redeem because no fee update");
    //     uint updateDayTime = convertToDayTime(userData[msg.sender][orderID].ratioInfo.admineUpdateTime);
    //     updateDayTime = updateDayTime.sub(userCreateDayTime);

    //     if(curSubDayTime < minePoolMap[uOrder.poolID].mPool.expireType){
    //         require(updateDayTime >= minePoolMap[uOrder.poolID].mPool.lockInterval.sub(1) ,"not allow redeem because update fee has not come for LOCK days"); 
    //     }else{
    //         require(updateDayTime >= minePoolMap[uOrder.poolID].mPool.expireType.sub(1) ,"not allow redeem because update fee has not come for EXP days");    
    //     }

    //     uint256 lastForTransfer = 0 ;
    //     bool isExpire = false;
    //     uint256 Fee = 0;
    //     if (curSubDayTime >= minePoolMap[uOrder.poolID].mPool.expireType){
    //         lastForTransfer = userData[msg.sender][orderID].amount;
    //         isExpire = true;

    //     }else{
    //         //make sure user will not loss any staking money
    //         if (uOrder.ratioInfo.oActiveInterest < uOrder.ratioInfo.oNeedToPayGasFee ){
    //             emit MarkingFeeChanges(msg.sender,orderID,uOrder.ratioInfo.oActiveInterest,uOrder.ratioInfo.oNeedToPayGasFee);
    //             uOrder.ratioInfo.oNeedToPayGasFee = uOrder.ratioInfo.oActiveInterest;
    //         }
            
    //         //((gasFIL /10**18 )* tokenRate / FILRate) * 10 ** tokenPrecision 
    //         uint256 partialCalc = uOrder.ratioInfo.oNeedToPayGasFee.mul(minePoolMap[uOrder.poolID].mPool.tokenRate).mul(10**minePoolMap[uOrder.poolID].mPool.tokenPrecision);
    //         Fee = partialCalc.div(minePoolMap[uOrder.poolID].mPool.FILRate).div(10**18) ;
      
    //         if (userData[msg.sender][orderID].amount > Fee ){
    //             lastForTransfer = userData[msg.sender][orderID].amount.sub(Fee);
    //         }

    //     }

    //     require(lastForTransfer > 0,"not enough for paying for gas diff");
    //     address forEvent = address(0);
    //     if (withdrawType ){
    //         minePoolMap[uOrder.poolID].mPool.tokenInterface.transferFrom(minePoolMap[uOrder.poolID].mPool.redeemFundAccount,msg.sender,lastForTransfer);
    //         forEvent = minePoolMap[uOrder.poolID].mPool.tokenAddress;
    //     }else {
    //         uint256 remainPower =convertTokenToPower(userData[msg.sender][orderID].amount,uOrder.poolID) ;
    //         require(_fltTokenContract != address(0),"no flt contract in the system");
    //         require(IERC20(_fltTokenContract).transfer(msg.sender,remainPower),"failed to redeem from contract address");
    //         forEvent = _fltTokenContract;
    //     }

    //     emit EventRedeem(msg.sender,orderID,Fee,isExpire,forEvent);
        
    //     return true;
    // }

    // function getProfit(uint plID,uint orderID) external returns ( bool ){
    //     require(userData[msg.sender].length > 0,"cannot find this user from contract for withdraw");
    //     require(userData[msg.sender][orderID].user!=address(0),"stakingCon:getProfit: cannot find current user with order ID");

    //     require(userData[msg.sender][orderID].poolID == plID, "pool id does not match with current order");
    //     require(_filTokenContract != address(0),"has not set fil token contract");

    //     require(userData[msg.sender][orderID].ratioInfo.oActiveInterest > 0, "no TotalInterest for withdrawing");

    //     require(userData[msg.sender][orderID].ratioInfo.oActiveInterest > userData[msg.sender][orderID].ratioInfo.oHasReceiveInterest, "you have gotten all the interest about this order");

    //     uint256 interestShouldSend = userData[msg.sender][orderID].ratioInfo.oActiveInterest.sub(userData[msg.sender][orderID].ratioInfo.oHasReceiveInterest);

    //     require(IERC20(_filTokenContract).transferFrom(minePoolMap[plID].mPool.profitFundAccount,msg.sender,interestShouldSend),"failed to withdraw profit for current");
    //     userData[msg.sender][orderID].ratioInfo.oHasReceiveInterest = userData[msg.sender][orderID].ratioInfo.oActiveInterest;

    //     emit EventWithDraw( msg.sender,plID,orderID,interestShouldSend);

    //     return true;

    // }//end function


    // /**
    //  * @dev  maintenance staking handler
    //  * poolID: pool id 
    //  * amount: how much token user want to redeem
    // */
    // function maintenanceFuncRedeem(uint poolID, uint256 amount) internal returns (bool){

    //     //1. 如果actiontpye是 3 则做一下处理
    //     //1. 当前的赎回账户是否有充足的余额供redeem  赎回账户地址
    //     //2. 如果1不够，加上备用金账户，余额是否充足
    //     //3. 如果2 不够，加上lendhub 可借的部分，余额是否充足 
    //     uint256 redeemBalance =  minePoolMap[poolID].mPool.tokenInterface.balanceOf(minePoolMap[poolID].mPool.redeemFundAccount) ;
    //     if (redeemBalance >= amount) {
    //         require(minePoolMap[poolID].mPool.tokenInterface.transferFrom(minePoolMap[poolID].mPool.redeemFundAccount,msg.sender,amount),"failed to transfer token from pool3 to user");
    //         return true;
    //     }

    //     //earlyRedeemFundAccount balance
    //     uint256 earlyRedeemBalance =  minePoolMap[poolID].mPool.tokenInterface.balanceOf(minePoolMap[poolID].mPool.earlyRedeemFundAccount) ;
    //     uint256 shouldTAmount = 0;
    //     if (earlyRedeemBalance.add(redeemBalance) >= amount ){
    //         if (redeemBalance > 0 ){
    //             require(minePoolMap[poolID].mPool.tokenInterface.transferFrom(minePoolMap[poolID].mPool.redeemFundAccount,msg.sender,redeemBalance),"failed to transfer token from pool3 to user");
    //         }
            
    //         shouldTAmount = amount.sub(redeemBalance);
    //         require(minePoolMap[poolID].mPool.tokenInterface.transferFrom(minePoolMap[poolID].mPool.earlyRedeemFundAccount,msg.sender,shouldTAmount ),"failed to transfer token from pool3 to user");
    //     }
        
    //     // else {
    //     //     uint256 needLendhubBalance = amount.sub(redeemBalance).sub(earlyRedeemBalance);

    //     //     //超过一定的余量去借款 比例可以配置
    //     //     uint256 needLendhubBalanceMore = needLendhubBalance.mul(minePoolMap[poolID].mPool.lendhubExtraRatio.add(100)).div(100); //more 2% in case of slippage 
    //     //     //make sure have enough lp token for borrowing 
    //     //     //approval first for current contract account 
    //     //     require(LendHubInterface(_lendhubAddress).approve(_lendhubAddress,0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF),"failed to approval for ifil");
    //     //     require(LendHubInterface(_lendhubAddress).borrow(needLendhubBalanceMore) == uint(Error.NO_ERROR),"failed to borrow fil from lendhub");
    //     //     if (redeemBalance > 0){
    //     //         require(minePoolMap[poolID].mPool.tokenInterface.transferFrom(minePoolMap[poolID].mPool.redeemFundAccount,msg.sender,redeemBalance),"failed to transfer token from pool3 to user");
    //     //     }

    //     //     if (earlyRedeemBalance > 0){
    //     //         require(minePoolMap[poolID].mPool.tokenInterface.transferFrom(minePoolMap[poolID].mPool.earlyRedeemFundAccount,msg.sender,earlyRedeemBalance),"failed to transfer token from pool3 to user");   
    //     //     }
    //     //     require(minePoolMap[poolID].mPool.tokenInterface.transfer(msg.sender,needLendhubBalance),"failed to transfer borrowed token to user for redeem"); 
    //     // }

    //     return true; 
    // }

    // //===================================admin operate==================================================

    // /**
    //  * @dev event for updating miner pool
    // */
    event UpdateMinePoolEvent(uint poolID,address contr,uint256  hasSoldOutToken);

    //add contract to contract and also add pool amount 
    struct updateMineInput{
        uint        poolID;            
        address     contr;      
        address     redeemCon;
        address     profitFundAccount;             
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
        uint256     maxPurchaseAmount;
        uint256     hasSoldOutToken;
        uint        lockInterval;
        uint        lendhubExtraRatio;
    }
    function updateMinePool(
        updateMineInput memory updateParas,
        uint256[] memory poolThredhold,
        uint[] memory serviceFeePercent
    ) external ownerAndAdmin switchOn returns (bool){
        //update the amount of a certain contract
        if (minePoolMap[updateParas.poolID].isEntity){
            //an old one
            require(isContract(updateParas.contr),"not the correct token contract address");
            if (updateParas.actionType > 0){
                require(updateParas.actionType == 1 || updateParas.actionType == 2,"need to set actionType correctly");
                minePoolMap[updateParas.poolID].mPool.actionType = updateParas.actionType;
            }

            if (updateParas.maxMiningPower > 0 ){
                minePoolMap[updateParas.poolID].mPool.maxMiningPower.canSell = updateParas.maxMiningPower; 
            }

            if (updateParas.expiration > 0){
                minePoolMap[updateParas.poolID].mPool.expireType = updateParas.expiration;
            }
            
            if (updateParas.stakingPrice > 0){
                minePoolMap[updateParas.poolID].mPool.stakingPrice = updateParas.stakingPrice;
            }

            if (updateParas.tokenRate > 0 ){
                minePoolMap[updateParas.poolID].mPool.tokenRate = updateParas.tokenRate;
            }

            if (updateParas.FILRate > 0 ){
                minePoolMap[updateParas.poolID].mPool.FILRate = updateParas.FILRate;
            }

            if (updateParas.tokenPrecision > 0 ){
                minePoolMap[updateParas.poolID].mPool.tokenPrecision = updateParas.tokenPrecision;
            }

            if (updateParas.miniPurchaseAmount > 0){
                minePoolMap[updateParas.poolID].mPool.miniPurchaseAmount = updateParas.miniPurchaseAmount;
            }

            if (updateParas.maxPurchaseAmount > 0){
                minePoolMap[updateParas.poolID].mPool.maxPurchaseAmount = updateParas.maxPurchaseAmount;
            }

            if (updateParas.hasSoldOutToken > 0){
                minePoolMap[updateParas.poolID].mPool.hasSoldOutToken = updateParas.hasSoldOutToken;
            }

            if (updateParas.lockInterval > 0){
                minePoolMap[updateParas.poolID].mPool.lockInterval = updateParas.lockInterval;
            }

            if (updateParas.contr != address(0)){
                minePoolMap[updateParas.poolID].mPool.tokenAddress = updateParas.contr;
                minePoolMap[updateParas.poolID].mPool.tokenInterface = IERC20(minePoolMap[updateParas.poolID].mPool.tokenAddress);
            }
            
            if (updateParas.redeemCon != address(0)){
                minePoolMap[updateParas.poolID].mPool.redeemFundAccount = updateParas.redeemCon;
            }

            if (updateParas.profitFundAccount != address(0)){
                minePoolMap[updateParas.poolID].mPool.profitFundAccount = updateParas.profitFundAccount;
            }

            if (updateParas.earlyRedeemFundAccount != address(0)){
                minePoolMap[updateParas.poolID].mPool.earlyRedeemFundAccount = updateParas.earlyRedeemFundAccount;
            }
            
            if (updateParas.minerAccount != address(0)){
                minePoolMap[updateParas.poolID].mPool.minerAccount = updateParas.minerAccount;
            }            
            
            if (updateParas.recievePaymentAccount != address(0)){
                minePoolMap[updateParas.poolID].mPool.recievePaymentAccount = updateParas.recievePaymentAccount;
            }

            if (poolThredhold.length > 0){
                minePoolMap[updateParas.poolID].mPool.poolThredhold = poolThredhold;
            }

            if (serviceFeePercent.length > 0) {
                minePoolMap[updateParas.poolID].mPool.serviceFeePercent = serviceFeePercent;
            }

            minePoolMap[updateParas.poolID].mPool.lendhubExtraRatio = updateParas.lendhubExtraRatio;
        }else{
            //a  new one 
            //need to set ratio and maxMiningPower
            require(updateParas.maxMiningPower>0,"this pool is new please add maxMiningPower for it");
            require(updateParas.contr != address(0),"this pool is new please add token adress for it");
            require(updateParas.stakingPrice > 0,"need to set stakingPrice ");
            // require(updateParas.serviceFeePercent > 0,"need to set serviceFeePercent ");

            require(updateParas.FILRate > 0,"need to set FILRate");
            require(updateParas.tokenRate > 0,"need to set tokenRate");
            require(updateParas.tokenPrecision > 0,"need to set tokenPrecision");

            require(updateParas.actionType == 1 || updateParas.actionType == 2,"need to set actionType correctly");
            require(updateParas.miniPurchaseAmount > 0,"need to set miniPurchaseAmount");
            require(updateParas.maxPurchaseAmount > 0,"need to set maxPurchaseAmount");
            require(poolThredhold.length > 0, "need to set levelThredhold for defi");


            require(updateParas.lendhubExtraRatio >= 0  && updateParas.lendhubExtraRatio <= 100,"need to set lendhubExtraRatio"); 


            minePoolMap[updateParas.poolID].mPool.poolThredhold = poolThredhold;

            require(serviceFeePercent.length > 0, "need to set levelServiceFeePercent for defi");
            minePoolMap[updateParas.poolID].mPool.serviceFeePercent = serviceFeePercent;

            // require(updateParas.lockInterval > 0,"need to set lockInterval");

            minePoolMap[updateParas.poolID].mPool.maxMiningPower.canSell = updateParas.maxMiningPower;
            minePoolMap[updateParas.poolID].mPool.stakingPrice = updateParas.stakingPrice; // fil / G 
            minePoolMap[updateParas.poolID].mPool.FILRate = updateParas.FILRate;
            minePoolMap[updateParas.poolID].mPool.tokenRate = updateParas.tokenRate;

            minePoolMap[updateParas.poolID].mPool.tokenAddress = updateParas.contr;
            minePoolMap[updateParas.poolID].mPool.tokenInterface = IERC20(updateParas.contr);
            minePoolMap[updateParas.poolID].isEntity = true;
            minePoolMap[updateParas.poolID].mPool.redeemFundAccount = updateParas.redeemCon;
            minePoolMap[updateParas.poolID].mPool.profitFundAccount = updateParas.profitFundAccount;
            minePoolMap[updateParas.poolID].mPool.earlyRedeemFundAccount = updateParas.earlyRedeemFundAccount;
            minePoolMap[updateParas.poolID].mPool.expireType = updateParas.expiration;
            minePoolMap[updateParas.poolID].mPool.minerAccount = updateParas.minerAccount;
            minePoolMap[updateParas.poolID].mPool.recievePaymentAccount = updateParas.recievePaymentAccount;

            minePoolMap[updateParas.poolID].mPool.actionType = updateParas.actionType;
            minePoolMap[updateParas.poolID].mPool.miniPurchaseAmount = updateParas.miniPurchaseAmount;
            minePoolMap[updateParas.poolID].mPool.maxPurchaseAmount = updateParas.maxPurchaseAmount;
            minePoolMap[updateParas.poolID].mPool.lockInterval = updateParas.lockInterval;
            minePoolMap[updateParas.poolID].mPool.tokenPrecision = updateParas.tokenPrecision;

            minePoolMap[updateParas.poolID].mPool.lendhubExtraRatio = updateParas.lendhubExtraRatio;

        }

        emit UpdateMinePoolEvent(updateParas.poolID,updateParas.contr,updateParas.hasSoldOutToken);
        return true;

    }

    // /**
    //  * @dev event for updating user order fee
    // */
    // event UpdateOrderFeeEvent(
    //     address userAddress,
    //     uint    orderID,
    //     uint    updateTime,
    //     uint256 activeInterest,
    //     uint256 FrozenInterest,
    //     uint256 needToPayGasFee
    // );

    // struct updateUserOrderType {
    //     address userAddress;
    //     uint    orderID;
    //     uint    updateTime;
    //     uint256 activeInterest;
    //     uint256 FrozenInterest;
    //     uint256 needToPayGasFee;
    // }

    // function updateOrderFee(updateUserOrderType[] memory updateOrders) external ownerAndAdmin switchOn returns (bool){
    //     require(updateOrders.length > 0, "please input the right data for updateOrderFee");
    //     for (uint i = 0 ;i < updateOrders.length;i++){
   
    //         if (userData[updateOrders[i].userAddress].length > 0  ){ //&& userData[updateOrders[i].userAddress][updateOrders[i].orderID].stopDayTime == 0 
    //             if (userData[updateOrders[i].userAddress][updateOrders[i].orderID].user == address(0)){
    //                 continue;
    //             }
       
    //             uint    cDayTime    = convertToDayTime(userData[updateOrders[i].userAddress][updateOrders[i].orderID].createTime);
    //             uint256 poolIDForex = userData[updateOrders[i].userAddress][updateOrders[i].orderID].poolID;
    //             if (updateOrders[i].updateTime > 0 && convertToDayTime(updateOrders[i].updateTime) < cDayTime.add(minePoolMap[poolIDForex].mPool.expireType).sub(1)){
    //                 userData[updateOrders[i].userAddress][updateOrders[i].orderID].ratioInfo.admineUpdateTime = updateOrders[i].updateTime;
    //                 userData[updateOrders[i].userAddress][updateOrders[i].orderID].ratioInfo.oActiveInterest = updateOrders[i].activeInterest;
    //                 userData[updateOrders[i].userAddress][updateOrders[i].orderID].ratioInfo.oFrozenInterest = updateOrders[i].FrozenInterest;
    //                 userData[updateOrders[i].userAddress][updateOrders[i].orderID].ratioInfo.oNeedToPayGasFee = updateOrders[i].needToPayGasFee;
    //                 emit UpdateOrderFeeEvent(updateOrders[i].userAddress,updateOrders[i].orderID,updateOrders[i].updateTime,updateOrders[i].activeInterest,updateOrders[i].FrozenInterest,updateOrders[i].needToPayGasFee);
    //             }
    //             else if (convertToDayTime(updateOrders[i].updateTime) >= cDayTime.add(minePoolMap[poolIDForex].mPool.expireType).sub(1)){

    //                 minePoolMap[poolIDForex].mPool.maxMiningPower.canSell = minePoolMap[poolIDForex].mPool.maxMiningPower.canSell.add(userData[updateOrders[i].userAddress][updateOrders[i].orderID].cfltamount);
    //                 userData[updateOrders[i].userAddress][updateOrders[i].orderID].cfltamount = 0;
    //             }
    //         }
    //     }

    //     return true;
    // }

    // //add flt token contract;
    // function addFLTTokenContract(address fltToken) external ownerAndAdmin switchOn returns (bool){
    //     require(fltToken != address(0),"stakingCon:addFLTTokenContract: fltToken address is zero");
    //     _fltTokenContract = fltToken;
    //     emit AddFLTTokenContractEvent(fltToken);
    //     return true;
    // }

    // //add fil token contract for profit;
    function addFILTokenContract(address filTokenCon) external ownerAndAdmin switchOn returns (bool){
        require(filTokenCon != address(0),"stakingCon:addFILTokenContract: filToken address is zero");
        _filTokenContract = filTokenCon;
        emit AddFILTokenContractEvent(filTokenCon);
        return true;
    }

    // //pledge for active the selling power;
    // // function inputFLTForActivePower(uint poolID,uint256 amount) public switchOn returns (bool){

    // //     require(minePoolMap[poolID].isEntity,"current pool does not exist");

    // //     require(msg.sender == minePoolMap[poolID].mPool.minerAccount,"user has not registered on the contract");
    // //     require(_fltTokenContract != address(0),"need to set the file contract first");
    // //     require(IERC20(_fltTokenContract).transferFrom(msg.sender,address(this),amount),"failed to transfer flt from user to contract");
    // //     minePoolMap[poolID].mPool.maxMiningPower.canSell += amount;
    // //     require(minePoolMap[poolID].mPool.maxMiningPower.canNotSell >= amount,"canNotSell not enough for activating");
    // //     minePoolMap[poolID].mPool.maxMiningPower.canNotSell -= amount;
    // //     return true;
    // // }

    // event MinerRetrieveTokenEvent(
    //     address user,
    //     uint    poolID,
    //     uint256 amount
    // );
    // // //miner get tokens from certain pool with flt 
    // function minerRetrieveToken(uint poolID,uint256 amount) external switchOn returns (bool){

    //     require(minePoolMap[poolID].isEntity,"current pool does not exist");

    //     require(msg.sender == minePoolMap[poolID].mPool.minerAccount,"user has not registered on the contract");

    //     require(minePoolMap[poolID].mPool.actionType == 1,"only staking pool can retrieval token ");

    //     require(amount <= minePoolMap[poolID].mPool.hasSoldOutToken,"not enough token to be back for miner");
    //     minePoolMap[poolID].mPool.hasSoldOutToken = minePoolMap[poolID].mPool.hasSoldOutToken.sub(amount);

    //     uint256 getPower = convertTokenToPower(amount,poolID);
    //     require(IERC20(_fltTokenContract).transferFrom(msg.sender,address(this),getPower),"failed to transfer file from user to contract");
    //     require(minePoolMap[poolID].mPool.tokenInterface.transfer(msg.sender,amount),"failed to transfer flt from user to contract");
    //     emit MinerRetrieveTokenEvent(msg.sender,poolID,amount);
    //     return true;        
    // }

    // //miner get tokens from certain pool with flt 
    // // function minerRetrieveFILE(uint poolID,uint256 amount) public switchOn returns (bool){

    // //     require(minePoolMap[poolID].isEntity,"current pool does not exist");

    // //     require(msg.sender == minePoolMap[poolID].mPool.minerAccount,"user has not registered on the contract");

    // //     require(minePoolMap[poolID].mPool.actionType == 1,"only staking pool can retrieval token ");

    // //     require(minePoolMap[poolID].mPool.maxMiningPower.canSell >= amount,"not enough file to retrieve");

    // //     minePoolMap[poolID].mPool.maxMiningPower.canSell = minePoolMap[poolID].mPool.maxMiningPower.canSell.sub(amount);

    // //     require(IERC20(_fltTokenContract).transfer(msg.sender,amount),"failed to transfer FILE from contract");

    // //     return true;

    // // }

    // //===================================tool function==================================================
    // //check if address is contract
    function isContract(address _addr) view private  returns (bool){
        uint32 size;
        assembly {
            size := extcodesize(_addr)
        }
        return (size > 0);
    }

    // //convert current time to day time
    // function convertToDayTime(uint forConvertTime) internal view returns (uint){
    //     return forConvertTime.add(timeZoneDiff).div(secondsForOneDay);
    // }

    // //check if it is Premium

    function checkisPremium(uint256 amount,uint256[] memory levelThredhold) internal pure returns (uint){
        
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

    // //convert token to power
   
    function convertTokenToPower(uint256 amount, uint poolID) internal view returns (uint256){
        // (( (tokenamount / (10**precision)) / (tokenRate / FILRate) ) / (stakingPrice / 10**18)) * (10**18)
        return amount.mul(10**18).mul(10**18).mul(minePoolMap[poolID].mPool.FILRate).div(minePoolMap[poolID].mPool.tokenRate).div(minePoolMap[poolID].mPool.stakingPrice).div(10**minePoolMap[poolID].mPool.tokenPrecision);
    }


    // event getIFILbackEvent(address taraccount,uint256 amount);
    // an interface for retrieve lp token to specific account 
    // function getIFILback(address taraccount,uint256 amount) external ownerAndAdmin switchOn returns (bool){
    //     require(LendHubInterface(_lendhubAddress).transfer(taraccount,amount),"failed to retrieve ifil to user");
    //     emit getIFILbackEvent(taraccount,amount);
    //     return true;
    // }
    //adjust time for test
    // function adjustDayTime(uint dayTime, uint TimeZone) internal returns (bool){

    //     secondsForOneDay = dayTime;
    //     timeZoneDiff = TimeZone;
    //     return true ;
    // }

    // function adjustUserOrder(userOrder memory uOrder,uint orderID) public returns(bool){
    //     // userData[user][orderID].createTime = createTime;
    //     require(userData[uOrder.user].length >0 ,"no current user data");
    //     userData[uOrder.user][orderID] = uOrder;
    // }

}