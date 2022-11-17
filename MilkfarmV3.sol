/*
    Milkfarm V3 - BSC BNB Miner
    Developed by Kraitor <TG: kraitordev>
*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "./BasicLibraries/SafeMath.sol";
import "./BasicLibraries/Auth.sol";
import "./BasicLibraries/IBEP20.sol";
import "./Libraries/MinerBasic.sol";
import "./Libraries/Airdrop.sol";
import "./Libraries/AutoEXE.sol";
import "./Libraries/InvestorsManager.sol";
import "./Libraries/Algorithm.sol";
import "./Libraries/MilkfarmV3ConfigIface.sol";
import "./Libraries/EmergencyWithdrawal.sol";
import "./Libraries/Migration.sol";
import "./Libraries/Testable.sol";

contract MilkfarmV3 is Auth, MinerBasic, AutoEXE, Algorithm, Airdrop, InvestorsManager, EmergencyWithdrawal, Migration, Testable {
    using SafeMath for uint256;
    using SafeMath for uint64;
    using SafeMath for uint32;
    using SafeMath for uint8;

    //External config iface (Roi events)
    milkfarmV3ConfigIface reIface;

    constructor(address _airdropToken, address _autoAdd, address _angAdr, address _recIface, address timerAddr) Auth(msg.sender) Testable(timerAddr) {
        recAdd = payable(msg.sender);
        autoAdd = payable(_autoAdd);
        angAdd = payable(_angAdr);
        airdropToken = _airdropToken;
        reIface = milkfarmV3ConfigIface(address(_recIface));
    }


    //CONFIG////////////////
    function setAirdropToken(address _airdropToken) public override authorized { airdropToken =_airdropToken; }
    function enableClaim(bool _enableClaim) public override authorized { claimEnabled = _enableClaim; }
    function setExecutionHour(uint32 exeHour) public override authorized { executionHour = exeHour; }
    function setMaxInvestorsPerExecution(uint64 maxInvPE) public override authorized { maxInvestorPerExecution = maxInvPE; }
    function enableSingleMode(bool _enable) public override authorized { enabledSingleMode = _enable; }
    function enablenMaxSellsRestriction(bool _enable) public override authorized { nMaxSellsRestriction = _enable; }
    function openToPublic(bool _openPublic) public override authorized { openPublic = _openPublic; }
    function setExternalConfigAddress(address _recIface) public authorized { reIface = milkfarmV3ConfigIface(address(_recIface)); }
    function renounceUnstuck() public authorized { renounce_unstuck = true; }
    function disableMigration() public override authorized { migrationEnabled = false; }
    function enableDisableInflation(bool enable) public authorized { disableInflation = enable; }
    function setAutotax(uint8 _autoFeeTax, address _autoAdd) public override authorized {
        require(_autoFeeTax <= 5);
        autoFeeTax = _autoFeeTax;
        autoAdd = payable(_autoAdd);
    }
    function setDevTax(uint8 _devFeeVal, address _devAdd) public authorized {
        require(_devFeeVal <= 5);
        devFeeVal = _devFeeVal;
        recAdd = payable(_devAdd);
    }
    function setTaxForAngel(uint8 _angTax, address _angAdr) public authorized {
        require(_angTax <= 5 && _angTax >= 2);
        angTax = _angTax;
        angAdd = payable(_angAdr);
    }
    function setAlgorithmLimits(uint8 _minDaysSell, uint8 _maxDaysSell) public override authorized {
        require(_minDaysSell >= 0 && _maxDaysSell <= 21, 'Limits not allowed');
        minDaysSell = _minDaysSell;
        maxDaysSell = _maxDaysSell;
    }
    function setEmergencyWithdrawPenalty(uint256 _penalty) public override authorized {
        require(_penalty < 100);
        emergencyWithdrawPenalty = _penalty;
    }
    function setMaxSellPc(uint256 _maxSellNum, uint256 _maxSellDiv) public authorized {
        require(uint256(1000).mul(_maxSellNum) >= _maxSellDiv, "Min max sell is 0.1% of TLV");
        maxSellNum = _maxSellNum;
        maxSellDiv = _maxSellDiv;
    }
    function setRewardsPercentage(uint32 _percentage) public authorized {
        require(_percentage >= 15, 'Percentage cannot be less than 15');
        rewardsPercentage = _percentage;
    }    
    function unstuck_bnb(uint256 _amount) public authorized { 
        require(!renounce_unstuck, "Unstuck renounced, can not withdraw funds"); //Testing/Security meassure
        payable(msg.sender).transfer(_amount); 
    }
    ////////////////////////

    //MIGRATION/////////////
    function restoreBase(uint256 _marketMilks) public override authorized { 
        require(migrationEnabled, 'Migration disabled');
        marketMilks = _marketMilks; 
    }

    function claimRestore() public override {
        require(migrationEnabled, 'Migration disabled');
        require(false, 'Not implemented');
        //Get milkers and referrals calling v2 miner
    }

    function performMigration(address [] memory address_restore, uint256 [] memory milkers) public override authorized {
        require(migrationEnabled, 'Migration disabled');
        require(address_restore.length == milkers.length, 'Arrays lengths does not match');

        for(uint _i = 0; _i < address_restore.length; _i++){
            initializeInvestor(address_restore[_i]);
            setInvestorHiredMilkers(address_restore[_i], milkers[_i]);
            //setInvestorReferral(address_restore[_i], referrals[_i]);
        }
    }
    ////////////////////////

    //AIRDROPS//////////////
    function claimMilkers(address ref) public override {
        require(initialized);
        require(claimEnabled || isAuthorized(msg.sender), 'Claim still not available');

        uint256 airdropTokens = IBEP20(airdropToken).balanceOf(msg.sender);
        IBEP20(airdropToken).transferFrom(msg.sender, address(this), airdropTokens); //The token has to be approved first
        IBEP20(airdropToken).burn(airdropTokens); //Tokens burned

        //MILKBNB is used to buy pigs (miners)
        uint256 pigsClaimed = calculateHireMilkers(airdropTokens, address(this).balance);

        setInvestorClaimedMilks(msg.sender, SafeMath.add(getInvestorData(msg.sender).claimedMilks, pigsClaimed));
        rehireMilkers(msg.sender, ref, true);

        emit ClaimMilkers(msg.sender, pigsClaimed, airdropTokens);
    }
    ////////////////////////

    //AUTO EXE//////////////
    function executeN(uint256 nInvestorsExecute) public override {
        require(initialized);
        require(msg.sender == autoAdd || isAuthorized(msg.sender), 'Only auto account can trigger this');    

        uint256 _daysForSelling = this.daysForSelling(getCurrentTime());
        uint256 _nSells = this.totalSoldsToday();
        uint64 nInvestors = getNumberInvestors();
        uint256 _nSellsMax = SafeMath.div(nInvestors, _daysForSelling).add(1);
        if(!nMaxSellsRestriction){ _nSellsMax = type(uint256).max; }
        uint256 _loopStop = investorsNextIndex.add(min(nInvestorsExecute, nInvestors));

        for(uint64 i = investorsNextIndex; i < _loopStop; i++) {
            
            investor memory investorData = getInvestorData(investorsNextIndex);
            bool _canSell = canSell(investorData.investorAddress, _daysForSelling);
            if(_canSell == false || _nSells >= _nSellsMax){
                rehireMilkers(investorData.investorAddress, address(0), false);
            }else{
                _nSells++;
                sellMilks(investorData.investorAddress);
            }

            investorsNextIndex++; //Next iteration we begin on first rehire or zero
            if(investorsNextIndex == nInvestors){
                investorsNextIndex = 0;
            }
        }

        emit Execute(msg.sender, nInvestors, _daysForSelling, _nSells, _nSellsMax);
    }

    function execute() public override {
        require(initialized);
        require(msg.sender == autoAdd || isAuthorized(msg.sender), 'Only auto account can trigger this');    

        uint256 _daysForSelling = this.daysForSelling(getCurrentTime());
        uint256 _nSells = this.totalSoldsToday();
        uint64 nInvestors = getNumberInvestors();
        uint256 _nSellsMax = SafeMath.div(nInvestors, _daysForSelling).add(1);
        if(!nMaxSellsRestriction){ _nSellsMax = type(uint256).max; }
        uint256 _loopStop = investorsNextIndex.add(min(maxInvestorPerExecution, nInvestors));

        for(uint64 i = investorsNextIndex; i < _loopStop; i++) {
            
            investor memory investorData = getInvestorData(investorsNextIndex);
            bool _canSell = canSell(investorData.investorAddress, _daysForSelling);
            if(_canSell == false || _nSells >= _nSellsMax){
                rehireMilkers(investorData.investorAddress, address(0), false);
            }else{
                _nSells++;
                sellMilks(investorData.investorAddress);
            }

            investorsNextIndex++; //Next iteration we begin on first rehire or zero
            if(investorsNextIndex == nInvestors){
                investorsNextIndex = 0;
            }
        }

        emit Execute(msg.sender, nInvestors, _daysForSelling, _nSells, _nSellsMax);
    }

    function executeAddresses(address [] memory investorsRun, bool forceSell) public override {
        require(initialized);
        require(msg.sender == autoAdd || isAuthorized(msg.sender), 'Only auto account can trigger this');  

        uint256 _daysForSelling = this.daysForSelling(getCurrentTime());
        uint256 _nSells = this.totalSoldsToday();
        uint64 nInvestors = getNumberInvestors();
        uint256 _nSellsMax = SafeMath.div(nInvestors, _daysForSelling).add(1);    
        if(!nMaxSellsRestriction){ _nSellsMax = type(uint256).max; }  

        for(uint64 i = 0; i < investorsRun.length; i++) {
            address _investorAdr = investorsRun[i];
            investor memory investorData = getInvestorData(_investorAdr);
            bool _canSell = canSell(investorData.investorAddress, _daysForSelling);
            if((_canSell == false || _nSells >= _nSellsMax) && forceSell == false){
                rehireMilkers(investorData.investorAddress, address(0), false);
            }else{
                _nSells++;
                sellMilks(investorData.investorAddress);
            }
        }

        emit Execute(msg.sender, nInvestors, _daysForSelling, _nSells, _nSellsMax);
    }

    function executeSingle() public override {
        require(initialized);
        require(enabledSingleMode || isAuthorized(msg.sender), 'Single mode not enabled');
        require(openPublic || isAuthorized(msg.sender), 'Miner still not opened');

        uint256 _daysForSelling = this.daysForSelling(getCurrentTime());        
        uint256 _nSellsMax = SafeMath.div(getNumberInvestors(), _daysForSelling).add(1);
        if(!nMaxSellsRestriction){ _nSellsMax = type(uint256).max; }
        uint256 _nSells = this.totalSoldsToday(); //How much investors sold today?
        bool _canSell = canSell(msg.sender, _daysForSelling);
        bool rehire = _canSell == false || _nSells >= _nSellsMax;

        if(rehire){
            rehireMilkers(msg.sender, address(0), false);
        }else{
            sellMilks(msg.sender);
        }

        emit ExecuteSingle(msg.sender, rehire);
    }

    function getExecutionPeriodicity() public view override returns(uint64) {
        uint64 nInvestors = getNumberInvestors();
        uint256 _div = min(nInvestors, max(maxInvestorPerExecution, 20));
        uint64 nExecutions = uint64(nInvestors.div(_div));
        if(nInvestors % _div != 0){ nExecutions++; }
        return uint64(minutesDay.div(nExecutions)); 
        //Executions periodicity in minutes (sleep after each execution)
        //We have to sell/rehire for all investors each day
    }
    ////////////////////////


    //Emergency withdraw////
    function emergencyWithdraw() public override {
        require(initialized);
        require(getInvestorData(msg.sender).withdrawal < getInvestorData(msg.sender).investment, 'You already recovered your investment');
        require(getInvestorData(msg.sender).hiredMilkers > 1, 'You cant use this function');
        uint256 amountToWithdraw = getInvestorData(msg.sender).investment.sub(getInvestorData(msg.sender).withdrawal);
        uint256 amountToWithdrawAfterTax = amountToWithdraw.mul(uint256(100).sub(emergencyWithdrawPenalty)).div(100);
        require(amountToWithdrawAfterTax > 0, 'There is nothing to withdraw');
        uint256 amountToWithdrawTaxed = amountToWithdraw.sub(amountToWithdrawAfterTax);

        addInvestorWithdrawal(msg.sender, amountToWithdraw);
        acumWithdrawal(getCurrentTime(), amountToWithdraw);
        setInvestorHiredMilkers(msg.sender, 1); //Burn

        if(amountToWithdrawTaxed > 0){
            recAdd.transfer(amountToWithdrawTaxed);
        }

        payable (msg.sender).transfer(amountToWithdrawAfterTax);

        emit EmergencyWithdraw(getInvestorData(msg.sender).investment, getInvestorData(msg.sender).withdrawal, amountToWithdraw, amountToWithdrawAfterTax, amountToWithdrawTaxed);
    }
    ////////////////////////


    //BASIC/////////////////
    function seedMarket() public payable authorized {
        require(marketMilks == 0);
        initialized = true;
        marketMilks = 108000000000;
    }

    function hireMilkers(address ref) public payable {
        require(initialized);
        require(openPublic || isAuthorized(msg.sender), 'Miner still not opened');

        _hireMilkers(ref, msg.sender, msg.value);
    }

    function rehireMilkers(address _sender, address ref, bool isClaim) private {
        require(initialized);

        if(ref == _sender) {
            ref = address(0);
        }
                
        if(getInvestorData(_sender).referral == address(0) && getInvestorData(_sender).referral != _sender) {
            setInvestorReferral(_sender, ref);
        }
        
        uint256 milksUsed = getMyMilks(_sender);
        uint256 newMilkers = SafeMath.div(milksUsed,MILKS_TO_HATCH_1MILKER);

        //We need this to iterate later on auto executions
        if(newMilkers > 0 && getInvestorData(_sender).hiredMilkers == 0){            
            initializeInvestor(_sender);
        }

        setInvestorHiredMilkers(_sender, SafeMath.add(getInvestorData(_sender).hiredMilkers, newMilkers));
        setInvestorClaimedMilks(_sender, 0);
        setInvestorLastHire(_sender, getCurrentTime());
        
        //send referral milks
        setInvestorMilksByReferral(getReferralData(_sender).investorAddress, getReferralData(_sender).referralMilks.add(SafeMath.div(milksUsed, 8)));
        setInvestorClaimedMilks(getReferralData(_sender).investorAddress, SafeMath.add(getReferralData(_sender).claimedMilks, SafeMath.div(milksUsed, 8))); 
        
        //boost market to nerf miners hoarding
        if(isClaim == false && !disableInflation){
            marketMilks=SafeMath.add(marketMilks, SafeMath.div(milksUsed, 5));
        }

        emit RehireMilkers(_sender, newMilkers, getInvestorData(_sender).hiredMilkers, getNumberInvestors(), getReferralData(_sender).claimedMilks, marketMilks, milksUsed);
    }
    
    function sellMilks(address _sender) private {
        require(initialized);

        uint256 milksLeft = 0;
        uint256 hasMilks = getMyMilks(_sender);
        uint256 milksValue = calculateMilkSell(hasMilks);
        (milksValue, milksLeft) = capToMaxSell(milksValue, hasMilks);
        uint256 sellTax = calculateBuySellTax(milksValue);
        uint256 penalty = getBuySellPenalty();

        setInvestorClaimedMilks(_sender, milksLeft);
        setInvestorLastHire(_sender, getCurrentTime());
        marketMilks = SafeMath.add(marketMilks,hasMilks);
        payBuySellTax(sellTax);
        addInvestorWithdrawal(_sender, SafeMath.sub(milksValue, sellTax));
        acumWithdrawal(getCurrentTime(), SafeMath.sub(milksValue, sellTax));
        payable (_sender).transfer(SafeMath.sub(milksValue,sellTax));

        // Push the timestamp
        setInvestorSellsTimestamp(_sender, getCurrentTime());
        setInvestorNsells(_sender, getInvestorData(_sender).nSells.add(1));
        registerSell();

        emit Sell(_sender, milksValue, SafeMath.sub(milksValue,sellTax), penalty);
    }

    function _hireMilkers(address _ref, address _sender, uint256 _amount) private {        
        uint256 milksBought = calculateHireMilkers(_amount, SafeMath.sub(address(this).balance, _amount));
            
        if(reIface.needUpdateEventBoostTimestamps()){
            reIface.updateEventsBoostTimestamps();
        }

        uint256 milksBSFee = calculateBuySellTax(milksBought);
        milksBought = SafeMath.sub(milksBought, milksBSFee);
        uint256 fee = calculateBuySellTax(_amount);        
        payBuySellTax(fee);
        setInvestorClaimedMilks(_sender, SafeMath.add(getInvestorData(_sender).claimedMilks, milksBought));
        addInvestorInvestment(_sender, _amount);
        acumInvestment(getCurrentTime(), _amount);
        rehireMilkers(_sender, _ref, false);

        emit Hire(_sender, milksBought, _amount);
    }

    function canSell(address _sender, uint256 _daysForSelling) public view returns (bool) {
        uint256 _lastSellTimestamp = 0;
        if(getInvestorData(_sender).sellsTimestamp > 0){
            _lastSellTimestamp = getInvestorData(_sender).sellsTimestamp;
        }
        else{
            return false;            
        }
        return getCurrentTime() > _lastSellTimestamp && getCurrentTime().sub(_lastSellTimestamp) > _daysForSelling.mul(1 days);
    }

    function totalSoldsToday() public view returns (uint256) {
        //Last 24h
        uint256 _soldsToday = 0;
        uint256 _time = getCurrentTime();
        uint256 hourTimestamp = getCurrHourTimestamp(_time);
        for(uint i=0; i < 24; i++){
            _soldsToday += dayHourSells[hourTimestamp];
            hourTimestamp -= 3600;
        }

        return _soldsToday;
    }

    function registerSell() private { dayHourSells[getCurrHourTimestamp(getCurrentTime())]++; }

    function capToMaxSell(uint256 milksValue, uint256 milks) public view returns(uint256, uint256){
        uint256 maxSell = address(this).balance.mul(maxSellNum).div(maxSellDiv);
        if(maxSell >= milksValue){
            return (milksValue, 0);
        }
        else{
            uint256 nMilksHire = calculateHireMilkersSimpleNoEvent(milksValue.sub(maxSell));
            if(nMilksHire <= milks){
                return (maxSell, milks.sub(nMilksHire));
            }
            else{
                return (maxSell, 0);
            }
        }     
    }

    function getRewardsPercentage() public view returns (uint32) { return rewardsPercentage; }

    function getMarketMilks() public view returns (uint256) {
        return marketMilks;
    }
    
    function milksRewards(address adr) public view returns(uint256) {
        uint256 hasMilks = getMyMilks(adr);
        uint256 milksValue = calculateMilkSell(hasMilks);
        return milksValue;
    }

    function milksRewardsIncludingTaxes(address adr) public view returns(uint256) {
        uint256 hasMilks = getMyMilks(adr);
        (uint256 milksValue,) = calculateMilkSellIncludingTaxes(hasMilks);
        return milksValue;
    }

    function getBuySellPenalty() public view returns (uint256) {
        return SafeMath.add(SafeMath.add(autoFeeTax, devFeeVal), angTax);
    }

    function calculateBuySellTax(uint256 amount) private view returns(uint256) {
        return SafeMath.div(SafeMath.mul(amount, getBuySellPenalty()), 100);
    }

    function payBuySellTax(uint256 amountTaxed) private {        
        uint256 buySellPenalty = getBuySellPenalty();        
        payable(recAdd).transfer(amountTaxed.mul(devFeeVal).div(buySellPenalty));        
        payable(autoAdd).transfer(amountTaxed.mul(autoFeeTax).div(buySellPenalty));        
        payable(angAdd).transfer(amountTaxed.mul(angTax).div(buySellPenalty));
    }

    function calculateTrade(uint256 rt,uint256 rs, uint256 bs) private view returns(uint256) {
        uint256 valueTrade = SafeMath.div(SafeMath.mul(PSN,bs),SafeMath.add(PSNH,SafeMath.div(SafeMath.add(SafeMath.mul(PSN,rs),SafeMath.mul(PSNH,rt)),rt)));
        if(rewardsPercentage > 15) {
            return SafeMath.div(SafeMath.mul(valueTrade,rewardsPercentage), 15);
        }

        return valueTrade;
    }
    
    function calculateMilkSell(uint256 milks) public view returns(uint256) {
        if(milks > 0){
            return calculateTrade(milks, marketMilks, address(this).balance);
        }
        else{
            return 0;
        }
    }

    function calculateMilkSellIncludingTaxes(uint256 milks) public view returns(uint256, uint256) {
        if(milks == 0){
            return (0,0);
        }
        uint256 totalTrade = calculateTrade(milks, marketMilks, address(this).balance);
        uint256 penalty = getBuySellPenalty();
        uint256 sellTax = calculateBuySellTax(totalTrade);

        return (
            SafeMath.sub(totalTrade, sellTax),
            penalty
        );
    }
    
    function calculateHireMilkers(uint256 eth,uint256 contractBalance) public view returns(uint256) {
        return reIface.applyROIEventBoost(calculateHireMilkersNoEvent(eth, contractBalance));
    }

    function calculateHireMilkersNoEvent(uint256 eth,uint256 contractBalance) public view returns(uint256) {
        return calculateTrade(eth, contractBalance, marketMilks);
    }
    
    function calculateHireMilkersSimple(uint256 eth) public view returns(uint256) {
        return calculateHireMilkers(eth, address(this).balance);
    }

    function calculateHireMilkersSimpleNoEvent(uint256 eth) public view returns(uint256) {
        return calculateHireMilkersNoEvent(eth, address(this).balance);
    }
    
    function isInitialized() public view returns (bool) {
        return initialized;
    }
    
    function getBalance() public view returns(uint256) {
        return address(this).balance;
    }
    
    function getMyMilks(address adr) public view returns(uint256) {
        return SafeMath.add(getInvestorData(adr).claimedMilks, getMilksSinceLastHire(adr));
    }
    
    function getMilksSinceLastHire(address adr) public view returns(uint256) {        
        uint256 secondsPassed=min(MILKS_TO_HATCH_1MILKER, SafeMath.sub(getCurrentTime(), getInvestorData(adr).lastHire));
        return SafeMath.mul(secondsPassed, getInvestorData(adr).hiredMilkers);
    }
    
    function min(uint256 a, uint256 b) private pure returns (uint256) {
        return a < b ? a : b;
    }

    function max(uint256 a, uint256 b) private pure returns (uint256) {
        return a < b ? b : a;
    }

    receive() external payable {}
    ////////////////////////
}