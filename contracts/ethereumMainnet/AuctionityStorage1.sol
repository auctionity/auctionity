pragma solidity ^0.5.4;

import "../CommonContract/AuctionityStorage0.sol";

contract AuctionityStorage1 is AuctionityStorage0 {
    // TokenContract => TokenIds => Users => amount
    mapping(address => mapping(uint256 => mapping(address => uint256))) tokens;

    bytes32[] public withdrawalVoucherList; // List of withdrawal voucher
    mapping(bytes32 => bool) public withdrawalVoucherSubmitted; // is withdrawal voucher is already submitted

    bytes32[] public auctionEndVoucherList; // List of auction end voucher
    mapping(bytes32 => bool) public auctionEndVoucherSubmitted; // is auction end voucher is already submitted

}
