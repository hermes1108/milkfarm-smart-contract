// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

abstract contract Migration {
    bool public migrationEnabled = true;

    //event MigrationDone(address _sender, uint256 _milkersAirdropped, uint256 _mmBNB);

    //Disable migration once we finished
    function disableMigration() public virtual;

    //Restore base miner data
    function restoreBase(uint256 marketMilks) public virtual;

    //Used for people in order to perform migration
    function claimRestore() public virtual;

    //Used for software to auto migrate //Initialize user and set milkers
    function performMigration(
        address[] memory adress_restore,
        uint256[] memory milkers
    ) public virtual;

    constructor() {}
}
