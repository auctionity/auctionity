pragma solidity ^0.5.4;

contract AuctionityStorage0 {
    // selector => delegate contract
    mapping(bytes4 => address) internal delegates;

    // If selector not found, fallback contract address
    address public proxyFallbackContract;

    address public contractOwner;
    address public oracle;

    bool public paused;

    uint8 public ethereumChainId;
    uint8 public auctionityChainId;
}
