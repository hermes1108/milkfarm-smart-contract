// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

contract InvestorsManager {
    //INVESTORS DATA
    uint64 private nInvestors = 0;
    mapping(address => investor) private investors; //Investor data mapped by address
    mapping(uint64 => address) private investors_addresses; //Investors addresses mapped by index

    struct investor {
        address investorAddress; //Investor address
        uint256 investment; //Total investor investment on miner (real BNB, presales/airdrops not taken into account)
        uint256 withdrawal; //Total investor withdraw BNB from the miner
        uint256 hiredMilkers; //Total hired pigs (miners)
        uint256 claimedMilks; //Total milks claimed (produced by miners)
        uint256 lastHire; //Last time you hired pigs
        uint256 sellsTimestamp; //Last time you sold your milks
        uint256 nSells; //Number of sells you did
        uint256 referralMilks; //Number of milks you got from people that used your referral address
        address referral; //Referral address you used for joining the miner
    }

    function initializeInvestor(address adr) internal {
        if (investors[adr].investorAddress != adr) {
            investors[adr].investorAddress = adr;
            investors[adr].sellsTimestamp = block.timestamp;
            investors_addresses[nInvestors] = adr;
            nInvestors++;
        }
    }

    function getNumberInvestors() public view returns (uint64) {
        return nInvestors;
    }

    function getInvestorData(uint64 investor_index)
        public
        view
        returns (investor memory)
    {
        return investors[investors_addresses[investor_index]];
    }

    function getInvestorData(address addr)
        public
        view
        returns (investor memory)
    {
        return investors[addr];
    }

    function getReferralData(address addr)
        public
        view
        returns (investor memory)
    {
        return investors[investors[addr].referral];
    }

    function setInvestorAddress(address addr) internal {
        investors[addr].investorAddress = addr;
    }

    function addInvestorInvestment(address addr, uint256 investment) internal {
        investors[addr].investment += investment;
    }

    function addInvestorWithdrawal(address addr, uint256 withdrawal) internal {
        investors[addr].withdrawal += withdrawal;
    }

    function setInvestorHiredMilkers(address addr, uint256 hiredMilkers)
        internal
    {
        investors[addr].hiredMilkers = hiredMilkers;
    }

    function setInvestorClaimedMilks(address addr, uint256 claimedMilks)
        internal
    {
        investors[addr].claimedMilks = claimedMilks;
    }

    function setInvestorMilksByReferral(address addr, uint256 milks) internal {
        investors[addr].referralMilks = milks;
    }

    function setInvestorLastHire(address addr, uint256 lastHire) internal {
        investors[addr].lastHire = lastHire;
    }

    function setInvestorSellsTimestamp(address addr, uint256 sellsTimestamp)
        internal
    {
        investors[addr].sellsTimestamp = sellsTimestamp;
    }

    function setInvestorNsells(address addr, uint256 nSells) internal {
        investors[addr].nSells = nSells;
    }

    function setInvestorReferral(address addr, address referral) internal {
        investors[addr].referral = referral;
    }

    constructor() {}
}
