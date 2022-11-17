// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

abstract contract Airdrop {
    address public airdropToken = address(0); //Will be used for performing old miner airdrops
    bool public claimEnabled = false;

    event ClaimMilkers(
        address _sender,
        uint256 _milkersToClaim,
        uint256 _mmBNB
    );

    //Enable/disable claim
    function enableClaim(bool _enableClaim) public virtual;

    //Used for people in order to claim their milks, the fake token is burned
    function claimMilkers(address ref) public virtual;

    function setAirdropToken(address _airdropToken) public virtual;

    constructor() {}
}
