// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

abstract contract MinerBasic {
    event Hire(address indexed adr, uint256 milks, uint256 amount);
    event Sell(
        address indexed adr,
        uint256 milks,
        uint256 amount,
        uint256 penalty
    );
    event RehireMilkers(
        address _investor,
        uint256 _newMilkers,
        uint256 _hiredMilkers,
        uint256 _nInvestors,
        uint256 _referralMilks,
        uint256 _marketMilks,
        uint256 _milksUsed
    );

    bool internal renounce_unstuck = false; //Testing/security meassure, owner should renounce after checking everything is working fine
    uint32 internal rewardsPercentage = 15; //Rewards increase to apply (hire/sell)
    uint32 internal MILKS_TO_HATCH_1MILKER = 576000; //576000/24*60*60 = 6.666 days to recover your investment (6.666*15 = 100%)
    uint16 internal PSN = 10000;
    uint16 internal PSNH = 5000;
    bool internal initialized = false;
    uint256 internal marketMilks; //This variable is responsible for inflation.
    //Number of milks on market (sold) rehire adds 20% of milks rehired

    address payable internal recAdd;
    uint8 internal devFeeVal = 1; //Dev fee
    address payable internal angAdd;
    uint8 internal angTax = 2; //Tax for lottery

    uint256 public maxSellNum = 20; //Max sell TVL num
    uint256 public maxSellDiv = 1000; //Max sell TVL div //For example: 20 and 1000 -> 20/1000 = 2/100 = 2% of TVL max sell

    //uint8 internal sellTaxVal = 4; //Sell fee //REMOVED, only have auto and dev fee
    bool public disableInflation = false;

    // This function is called by anyone who want to contribute to TVL
    function ContributeToTVL() public payable {}

    //Open/close miner
    bool public openPublic = false;

    function openToPublic(bool _openPublic) public virtual;

    constructor() {}
}
