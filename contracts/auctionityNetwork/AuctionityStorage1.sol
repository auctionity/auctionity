pragma solidity ^0.5.4;

import "../CommonContract/AuctionityStorage0.sol";

contract AuctionityStorage1 is AuctionityStorage0 {
    struct WithdrawalData {
        mapping(bytes32 => uint16) withdrawalVoucher; // Mapping of withdrawalVoucherHash => position into withdrawalVoucherList
        bytes[] withdrawalVoucherList; // List of withdrawalVoucher
    }

    // Amount of locked deposit of auction
    struct TokenLockedData {
        uint256 amount;
        bool isValue;
    }

    struct TokenData {
        uint amount;
        // LockedFor => amount
        mapping(uint256 => TokenLockedData) lockedData; // Locked amount on auction smart contract
        uint256[] lockedList; // List of auctionId with a locked amount
    }

    mapping(address => mapping(uint256 => mapping(address => TokenData))) tokens;

    mapping(address => WithdrawalData) withdrawals;

    mapping(bytes32 => bool) depositTransactionHash;

}
