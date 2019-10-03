pragma solidity ^0.5.4;

import "../CommonContract/AuctionityInternalDelegates_V1.sol";
import "../CommonContract/SafeMath.sol";
import "../CommonContract/SafeMath96.sol";
import "../CommonContract/SafeMath32.sol";
import "../CommonContract/SafeMath16.sol";
import "../CommonContract/SafeMath8.sol";

contract AuctionityAuctions_V1 is AuctionityInternalDelegates_V1 {
    using SafeMath for uint256;
    using SafeMath96 for uint96;
    using SafeMath32 for uint32;
    using SafeMath16 for uint16;
    using SafeMath8 for uint8;

    bytes32 private constant AUCTION_TYPE_SLOT                  = keccak256("auction.type");
    bytes32 private constant AUCTION_TYPE_ENGLISH               = keccak256("auction.type:english");

    bytes32 private constant AUCTION_SELLER_SLOT                = keccak256("auction.seller");
    bytes32 private constant AUCTION_TOKENS_SLOT                = keccak256("auction.tokens");
    bytes32 private constant AUCTION_CURRENCY_SLOT              = keccak256("auction.currency");

    bytes32 private constant AUCTION_TIME_BEGIN                 = keccak256("auction.time.begin");
    bytes32 private constant AUCTION_TIME_END                   = keccak256("auction.time.end");
    bytes32 private constant AUCTION_INITIAL_TIME_END           = keccak256("auction.initial.time.end");
    bytes32 private constant AUCTION_ANTISNIPPING_TRIGGER       = keccak256("auction.antisnipping.trigger");
    bytes32 private constant AUCTION_ANTISNIPPING_DURATION      = keccak256("auction.antisnipping.duration");
    bytes32 private constant AUCTION_BID_INCREMENT              = keccak256("auction.bid.increment");

    bytes32 private constant AUCTION_SPONSOR                            = keccak256("auction.sponsor");
    bytes32 private constant AUCTION_REWARDS_COMMUNITY                  = keccak256("auction.rewards.community");
    bytes32 private constant AUCTION_REWARDS_AUCTION_SPONSOR            = keccak256("auction.rewards.auction.sponsor");
    bytes32 private constant AUCTION_REWARDS_BID_SPONSOR                = keccak256("auction.rewards.bid.sponsor");
    bytes32 private constant AUCTION_REWARDS_BID_AUCTIONEER             = keccak256("auction.rewards.bid.auctioneer");
    bytes32 private constant AUCTION_REWARDS_LAST_BID_SPONSOR           = keccak256("auction.rewards.last.bid.sponsor");
    bytes32 private constant AUCTION_REWARDS_COMMUNITY_AMOUNT           = keccak256("auction.rewards.community.amount");
    bytes32 private constant AUCTION_REWARDS_AUCTION_SPONSOR_AMOUNT     = keccak256("auction.rewards.auction.sponsor.amount");
    bytes32 private constant AUCTION_REWARDS_BID_SPONSOR_AMOUNT         = keccak256("auction.rewards.bid.sponsor.amount");
    bytes32 private constant AUCTION_REWARDS_BID_AUCTIONEER_AMOUNT      = keccak256("auction.rewards.bid.auctioneer.amount");
    bytes32 private constant AUCTION_REWARDS_LAST_BID_SPONSOR_AMOUNT    = keccak256("auction.rewards.last.bid.sponsor.amount");
    bytes32 private constant AUCTION_SELLER_AMOUNT                      = keccak256("auction.seller.amount");

    bytes32 private constant AUCTION_TRANSFER_REWARDS_AUCTION_SPONSOR      = keccak256("auction.transfer.rewards.auction.sponsor");
    bytes32 private constant AUCTION_TRANSFER_REWARDS_LAST_BID_SPONSOR     = keccak256("auction.transfer.rewards.last.bid.sponsor");
    bytes32 private constant AUCTION_TRANSFER_REWARDS_BID_SPONSOR          = keccak256("auction.transfer.rewards.bid.sponsor");
    bytes32 private constant AUCTION_TRANSFER_REWARDS_BID_AUCTIONEER       = keccak256("auction.transfer.rewards.bid.auctioneer");
    bytes32 private constant AUCTION_TRANSFER_TOKENS                       = keccak256("auction.transfer.tokens");
    bytes32 private constant AUCTION_TRANSFER_AMOUNT_TO_THE_SELLER         = keccak256("auction.transfer.amount.to.the.seller");

    bytes32 private constant AUCTION_CURRENT_AMOUNT             = keccak256("auction.current.amount");
    bytes32 private constant AUCTION_CURRENT_LEADER             = keccak256("auction.current.leader");

    bytes32 private constant AUCTION_BID_COUNT                  = keccak256("auction.bid.count");
    bytes32 private constant AUCTION_BIDS_USER                  = keccak256("auction.bids.user");
    bytes32 private constant AUCTION_BIDS_AMOUNT                = keccak256("auction.bids.amount");
    bytes32 private constant AUCTION_BIDS_SPONSOR               = keccak256("auction.bids.sponsor");
    bytes32 private constant AUCTION_BIDS_AUCTIONEER            = keccak256("auction.bids.auctioneer");
    bytes32 private constant AUCTION_BIDS_TIMESTAMP             = keccak256("auction.bids.timestamp");
    bytes32 private constant AUCTION_LAST_SPONSOR_FOR_BIDDER    = keccak256("auction.last.sponsor.for.bidder");

    bytes32 private constant AUCTION_ENDED                      = keccak256("auction.ended");

    event LogAuctionCreateEnglish_V1(
        bytes16 auctionId,
        address currencyContractAddress,
        uint256 currencyId,
        uint256 currencyAmount,
        uint32 timeBegin,
        uint32 timeEnd
    );

    event LogAuctionCreateEnglishBidding_V1(
        bytes16 auctionId,
        uint24 antisnippingTrigger,
        uint16 antisnippingDuration,
        uint256 bidIncrement
    );


    event LogAuctionCreateEnglishReward_V1(
        bytes16 auctionId,
        address sponsor,
        uint8 rewardCommunity,
        uint8 rewardAuctionSponsor,
        uint8 rewardBidSponsor,
        uint8 rewardBidAuctioneer,
        uint8 rewardLastBidSponsor
    );

    event LogAuctionCreateEnglishTokens_V1(
        bytes16 auctionId,
        address[] tokenContractAddress,
        uint256[] tokenId,
        uint256[] tokenAmount
    );


    event LogBid_V1(
        bytes16 auctionId,
        uint256 bidIndex,
        address bidder,
        uint256 amount,
        uint256 minimal,
        address sponsor,
        address auctioneer
    );

    event LogAntiSnippingTriggered_V1(
        bytes16 auctionId,
        uint32 timeEnd
    );

    event LogAuctionClosed_V1(
        bytes16 auctionId,
        address winner,
        uint256 amount,
        uint32 timeEnd
    );

    struct Token {
        address contractAddress;
        uint256 id;
        uint256 amount;
    }

    function getAuctionType_V1(bytes16 auctionId) public view returns (bytes32 auctionType) {
        bytes32 slot = keccak256(abi.encode(AUCTION_TYPE_SLOT, auctionId));
        assembly {
            auctionType := sload(slot)
        }
    }

    function _setAuctionType_V1(bytes16 auctionId, bytes32 auctionType) internal {
        bytes32 slot = keccak256(abi.encode(AUCTION_TYPE_SLOT, auctionId));
        assembly {
            sstore(slot, auctionType)
        }
    }

    function getAuctionSeller_V1(bytes16 auctionId) public view returns (address seller) {
        bytes32 slot = keccak256(abi.encode(AUCTION_SELLER_SLOT, auctionId));
        assembly {
            seller := sload(slot)
        }
    }

    function _setAuctionSeller_V1(bytes16 auctionId, address seller) internal {
        bytes32 slot = keccak256(abi.encode(AUCTION_SELLER_SLOT, auctionId));
        assembly {
            sstore(slot, seller)
        }
    }

    function getAuctionTokensCount_V1(bytes16 auctionId) public view returns (uint16 count) {
        bytes32 slot = keccak256(abi.encode(AUCTION_TOKENS_SLOT, auctionId));
        assembly {
            count := sload(slot)
        }
    }

    function _setAuctionTokensCount_V1(bytes16 auctionId, uint16 count) internal {
        bytes32 slot = keccak256(abi.encode(AUCTION_TOKENS_SLOT, auctionId));
        assembly {
            sstore(slot, count)
        }
    }

    function _getAuctionToken_V1(bytes16 auctionId, uint256 tokenIndex) internal view returns (Token memory token) {
        bytes32 slot = keccak256(abi.encode(AUCTION_TOKENS_SLOT, auctionId, tokenIndex));
        assembly {
            mstore(token, sload(slot))
            mstore(add(token, 0x20), sload(add(slot, 1)))
            mstore(add(token, 0x40), sload(add(slot, 2)))
        }

        return token;
    }

    function getAuctionTokenContractAddress_V1(bytes16 auctionId, uint256 tokenIndex) public view returns (address contractAddress) {
        return _getAuctionToken_V1(auctionId, tokenIndex).contractAddress;
    }

    function getAuctionTokenId_V1(bytes16 auctionId, uint256 tokenIndex) public view returns (uint256 id) {
        return _getAuctionToken_V1(auctionId, tokenIndex).id;
    }

    function getAuctionTokenAmount_V1(bytes16 auctionId, uint256 tokenIndex) public view returns (uint256 amount) {
        return _getAuctionToken_V1(auctionId, tokenIndex).amount;
    }

    function _setAuctionToken_V1(bytes16 auctionId, uint256 tokenIndex, Token memory token) internal {
        bytes32 slot = keccak256(abi.encode(AUCTION_TOKENS_SLOT, auctionId, tokenIndex));
        assembly {
            sstore(slot, mload(token))
            sstore(add(slot, 1), mload(add(token, 0x20)))
            sstore(add(slot, 2), mload(add(token, 0x40)))
        }
    }

    function _getAuctionCurrency_V1(bytes16 auctionId) internal view returns (Token memory currency) {
        bytes32 slot = keccak256(abi.encode(AUCTION_CURRENCY_SLOT, auctionId));
        assembly {
            mstore(currency, sload(slot))
            mstore(add(currency, 0x20), sload(add(slot, 1)))
            mstore(add(currency, 0x40), sload(add(slot, 2)))
        }
        return currency;
    }

    function getAuctionCurrencyContractAddress_V1(bytes16 auctionId) public view returns (address contractAddress) {
        return _getAuctionCurrency_V1(auctionId).contractAddress;
    }

    function getAuctionCurrencyId_V1(bytes16 auctionId) public view returns (uint256 id) {
        return _getAuctionCurrency_V1(auctionId).id;
    }

    function getAuctionCurrencyAmount_V1(bytes16 auctionId) public view returns (uint256 amount) {
        return _getAuctionCurrency_V1(auctionId).amount;
    }

    function _setAuctionCurrency_V1(bytes16 auctionId, Token memory currency) internal {
        bytes32 slot = keccak256(abi.encode(AUCTION_CURRENCY_SLOT, auctionId));
        assembly {
            sstore(slot, mload(currency))
            sstore(add(slot, 1), mload(add(currency, 0x20)))
            sstore(add(slot, 2), mload(add(currency, 0x40)))
        }
    }

    function getAuctionTimeBegin_V1(bytes16 auctionId) public view returns (uint32 time) {
        bytes32 slot = keccak256(abi.encode(AUCTION_TIME_BEGIN, auctionId));
        assembly {
            time := sload(slot)
        }
    }

    function _setAuctionTimeBegin_V1(bytes16 auctionId, uint32 time) internal {
        bytes32 slot = keccak256(abi.encode(AUCTION_TIME_BEGIN, auctionId));
        assembly {
            sstore(slot, time)
        }
    }

    function getAuctionTimeEnd_V1(bytes16 auctionId) public view returns (uint32 time) {
        bytes32 slot = keccak256(abi.encode(AUCTION_TIME_END, auctionId));
        assembly {
            time := sload(slot)
        }
    }

    function _setAuctionTimeEnd_V1(bytes16 auctionId, uint32 time) internal {
        bytes32 slot = keccak256(abi.encode(AUCTION_TIME_END, auctionId));
        assembly {
            sstore(slot, time)
        }
    }

    function getAuctionInitialTimeEnd_V1(bytes16 auctionId) public view returns (uint32 time) {
        bytes32 slot = keccak256(abi.encode(AUCTION_INITIAL_TIME_END, auctionId));
        assembly {
            time := sload(slot)
        }
    }

    function _setAuctionInitialTimeEnd_V1(bytes16 auctionId, uint32 time) internal {
        bytes32 slot = keccak256(abi.encode(AUCTION_INITIAL_TIME_END, auctionId));
        assembly {
            sstore(slot, time)
        }
    }

    function getAuctionAntiSnippingTrigger_V1(bytes16 auctionId) public view returns (uint24 trigger) {
        bytes32 slot = keccak256(abi.encode(AUCTION_ANTISNIPPING_TRIGGER, auctionId));
        assembly {
            trigger := sload(slot)
        }
    }

    function _setAuctionAntiSnippingTrigger_V1(bytes16 auctionId, uint24 trigger) internal {
        bytes32 slot = keccak256(abi.encode(AUCTION_ANTISNIPPING_TRIGGER, auctionId));
        assembly {
            sstore(slot, trigger)
        }
    }

    function getAuctionAntiSnippingDuration_V1(bytes16 auctionId) public view returns (uint16 duration) {
        bytes32 slot = keccak256(abi.encode(AUCTION_ANTISNIPPING_DURATION, auctionId));
        assembly {
            duration := sload(slot)
        }
    }

    function _setAuctionAntiSnippingDuration_V1(bytes16 auctionId, uint16 duration) internal {
        bytes32 slot = keccak256(abi.encode(AUCTION_ANTISNIPPING_DURATION, auctionId));
        assembly {
            sstore(slot, duration)
        }
    }

    function getAuctionBidIncrement_V1(bytes16 auctionId) public view returns (uint256 increment) {
        bytes32 slot = keccak256(abi.encode(AUCTION_BID_INCREMENT, auctionId));
        assembly {
            increment := sload(slot)
        }
    }

    function _setAuctionBidIncrement_V1(bytes16 auctionId, uint256 increment) internal {
        bytes32 slot = keccak256(abi.encode(AUCTION_BID_INCREMENT, auctionId));
        assembly {
            sstore(slot, increment)
        }
    }

    function getAuctionSponsor_V1(bytes16 auctionId) public view returns (address sponsor) {
        bytes32 slot = keccak256(abi.encode(AUCTION_SPONSOR, auctionId));
        assembly {
            sponsor := sload(slot)
        }
    }

    function _setAuctionSponsor(bytes16 auctionId, address sponsor) internal {
        bytes32 slot = keccak256(abi.encode(AUCTION_SPONSOR, auctionId));
        assembly {
            sstore(slot, sponsor)
        }
    }


    function getAuctionRewardCommunity_V1(bytes16 auctionId) public view returns (uint8 value) {
        bytes32 slot = keccak256(abi.encode(AUCTION_REWARDS_COMMUNITY, auctionId));
        assembly {
            value := sload(slot)
        }
        return value;
    }


    function _setAuctionRewardCommunity_V1(bytes16 auctionId, uint8 value) internal {
        bytes32 slot = keccak256(abi.encode(AUCTION_REWARDS_COMMUNITY, auctionId));
        assembly {
            sstore(slot, value)
        }
    }


    function getAuctionRewardAuctionSponsor_V1(bytes16 auctionId) public view returns (uint8 value) {
        bytes32 slot = keccak256(abi.encode(AUCTION_REWARDS_AUCTION_SPONSOR, auctionId));
        assembly {
            value := sload(slot)
        }
        return value;
    }

    function _setAuctionRewardAuctionSponsor_V1(bytes16 auctionId, uint8 value) internal {
        bytes32 slot = keccak256(abi.encode(AUCTION_REWARDS_AUCTION_SPONSOR, auctionId));
        assembly {
            sstore(slot, value)
        }
    }

    function getAuctionRewardBidAuctioneer_V1(bytes16 auctionId) public view returns (uint8 value) {
        bytes32 slot = keccak256(abi.encode(AUCTION_REWARDS_BID_AUCTIONEER, auctionId));
        assembly {
            value := sload(slot)
        }
        return value;
    }

    function _setAuctionRewardBidAuctioneer_V1(bytes16 auctionId, uint8 value) internal {
        bytes32 slot = keccak256(abi.encode(AUCTION_REWARDS_BID_AUCTIONEER, auctionId));
        assembly {
            sstore(slot, value)
        }
    }

    function getAuctionRewardBidSponsor_V1(bytes16 auctionId) public view returns (uint8 value) {
        bytes32 slot = keccak256(abi.encode(AUCTION_REWARDS_BID_SPONSOR, auctionId));
        assembly {
            value := sload(slot)
        }
        return value;
    }

    function _setAuctionRewardBidSponsor(bytes16 auctionId, uint8 value) internal {
        bytes32 slot = keccak256(abi.encode(AUCTION_REWARDS_BID_SPONSOR, auctionId));
        assembly {
            sstore(slot, value)
        }
    }

    function getAuctionRewardLastBidSponsor_V1(bytes16 auctionId) public view returns (uint8 value) {
        bytes32 slot = keccak256(abi.encode(AUCTION_REWARDS_LAST_BID_SPONSOR, auctionId));
        assembly {
            value := sload(slot)
        }
        return value;
    }

    function _setAuctionRewardLastBidSponsor_V1(bytes16 auctionId, uint8 value) internal {
        bytes32 slot = keccak256(abi.encode(AUCTION_REWARDS_LAST_BID_SPONSOR, auctionId));
        assembly {
            sstore(slot, value)
        }
    }

    function getAuctionRewardCommunityAmount_V1(bytes16 auctionId) public view returns (uint256 value) {
        bytes32 slot = keccak256(abi.encode(AUCTION_REWARDS_COMMUNITY_AMOUNT, auctionId));
        assembly {
            value := sload(slot)
        }
        return value;
    }


    function _setAuctionRewardCommunityAmount_V1(bytes16 auctionId, uint256 value) internal {
        bytes32 slot = keccak256(abi.encode(AUCTION_REWARDS_COMMUNITY_AMOUNT, auctionId));
        assembly {
            sstore(slot, value)
        }
    }


    function getAuctionRewardAuctionSponsorAmount_V1(bytes16 auctionId) public view returns (uint256 value) {
        bytes32 slot = keccak256(abi.encode(AUCTION_REWARDS_AUCTION_SPONSOR_AMOUNT, auctionId));
        assembly {
            value := sload(slot)
        }
        return value;
    }

    function _setAuctionRewardAuctionSponsorAmount_V1(bytes16 auctionId, uint256 value) internal {
        bytes32 slot = keccak256(abi.encode(AUCTION_REWARDS_AUCTION_SPONSOR_AMOUNT, auctionId));
        assembly {
            sstore(slot, value)
        }
    }

    function getAuctionRewardBidAuctioneerAmount_V1(bytes16 auctionId) public view returns (uint256 value) {
        bytes32 slot = keccak256(abi.encode(AUCTION_REWARDS_BID_AUCTIONEER_AMOUNT, auctionId));
        assembly {
            value := sload(slot)
        }
        return value;
    }

    function _setAuctionRewardBidAuctioneerAmount_V1(bytes16 auctionId, uint256 value) internal {
        bytes32 slot = keccak256(abi.encode(AUCTION_REWARDS_BID_AUCTIONEER_AMOUNT, auctionId));
        assembly {
            sstore(slot, value)
        }
    }

    function getAuctionRewardBidSponsorAmount_V1(bytes16 auctionId) public view returns (uint256 value) {
        bytes32 slot = keccak256(abi.encode(AUCTION_REWARDS_BID_SPONSOR_AMOUNT, auctionId));
        assembly {
            value := sload(slot)
        }
        return value;
    }

    function _setAuctionRewardBidSponsorAmount_V1(bytes16 auctionId, uint256 value) internal {
        bytes32 slot = keccak256(abi.encode(AUCTION_REWARDS_BID_SPONSOR_AMOUNT, auctionId));
        assembly {
            sstore(slot, value)
        }
    }

    function getAuctionRewardLastBidSponsorAmount_V1(bytes16 auctionId) public view returns (uint256 value) {
        bytes32 slot = keccak256(abi.encode(AUCTION_REWARDS_LAST_BID_SPONSOR_AMOUNT, auctionId));
        assembly {
            value := sload(slot)
        }
        return value;
    }

    function _setAuctionRewardLastBidSponsorAmount_V1(bytes16 auctionId, uint256 value) internal {
        bytes32 slot = keccak256(abi.encode(AUCTION_REWARDS_LAST_BID_SPONSOR_AMOUNT, auctionId));
        assembly {
            sstore(slot, value)
        }
    }

    function getAuctionSellerAmount_V1(bytes16 auctionId) public view returns (uint256 value) {
        bytes32 slot = keccak256(abi.encode(AUCTION_SELLER_AMOUNT, auctionId));
        assembly {
            value := sload(slot)
        }
        return value;
    }

    function _setAuctionSellerAmount_V1(bytes16 auctionId, uint256 value) internal {
        bytes32 slot = keccak256(abi.encode(AUCTION_SELLER_AMOUNT, auctionId));
        assembly {
            sstore(slot, value)
        }
    }


    function getAuctionEnded_V1(bytes16 auctionId) public view returns (bool value) {
        bytes32 slot = keccak256(abi.encode(AUCTION_ENDED, auctionId));
        assembly {
            value := sload(slot)
        }
        return value;
    }

    function _setAuctionEnded_V1(bytes16 auctionId, bool value) internal {
        bytes32 slot = keccak256(abi.encode(AUCTION_ENDED, auctionId));
        assembly {
            sstore(slot, value)
        }
    }

    function getAuctionBidCount_V1(bytes16 auctionId) public view returns (uint256 value) {
        bytes32 slot = keccak256(abi.encode(AUCTION_BID_COUNT, auctionId));
        assembly {
            value := sload(slot)
        }
        return value;
    }

    function _addAuctionNewBid_V1(bytes16 auctionId) internal returns (uint256 value) {
        bytes32 slot = keccak256(abi.encode(AUCTION_BID_COUNT, auctionId));
        assembly {
            value := sload(slot)
        }
        value++;
        assembly {
            sstore(slot, value)
        }
    }

    function getAuctionCurrentAmount_V1(bytes16 auctionId) public view returns (uint256 value) {
        bytes32 slot = keccak256(abi.encode(AUCTION_CURRENT_AMOUNT, auctionId));
        assembly {
            value := sload(slot)
        }
        return value;
    }

    function _setAuctionCurrentAmount_V1(bytes16 auctionId, uint256 value) internal {
        bytes32 slot = keccak256(abi.encode(AUCTION_CURRENT_AMOUNT, auctionId));
        assembly {
            sstore(slot, value)
        }
    }

    function getAuctionBidsUser_V1(bytes16 auctionId, uint256 bidIndex) public view returns (address user) {
        bytes32 slot = keccak256(abi.encode(AUCTION_BIDS_USER, auctionId, bidIndex));
        assembly {
            user := sload(slot)
        }
        return user;
    }

    function _setAuctionBidsUser_V1(bytes16 auctionId, uint256 bidIndex, address user) internal {
        bytes32 slot = keccak256(abi.encode(AUCTION_BIDS_USER, auctionId, bidIndex));
        assembly {
            sstore(slot, user)
        }
    }

    function getAuctionBidsAmount_V1(bytes16 auctionId, uint256 bidIndex) public view returns (uint256 value) {
        bytes32 slot = keccak256(abi.encode(AUCTION_BIDS_AMOUNT, auctionId, bidIndex));
        assembly {
            value := sload(slot)
        }
        return value;
    }

    function _setAuctionBidsAmount_V1(bytes16 auctionId, uint256 bidIndex, uint256 value) internal {
        bytes32 slot = keccak256(abi.encode(AUCTION_BIDS_AMOUNT, auctionId, bidIndex));
        assembly {
            sstore(slot, value)
        }
    }

    function getAuctionBidsSponsor_V1(bytes16 auctionId, uint256 bidIndex) public view returns (address sponsor) {
        bytes32 slot = keccak256(abi.encode(AUCTION_BIDS_SPONSOR, auctionId, bidIndex));
        assembly {
            sponsor := sload(slot)
        }
        return sponsor;
    }

    function _setAuctionBidsSponsor_V1(bytes16 auctionId, uint256 bidIndex, address sponsor) internal {
        bytes32 slot = keccak256(abi.encode(AUCTION_BIDS_SPONSOR, auctionId, bidIndex));
        assembly {
            sstore(slot, sponsor)
        }
    }

    function getAuctionBidsAuctioneer_V1(bytes16 auctionId, uint256 bidIndex) public view returns (address auctioneer) {
        bytes32 slot = keccak256(abi.encode(AUCTION_BIDS_AUCTIONEER, auctionId, bidIndex));
        assembly {
            auctioneer := sload(slot)
        }
        return auctioneer;
    }

    function _setAuctionBidsAuctioneer_V1(bytes16 auctionId, uint256 bidIndex, address auctioneer) internal {
        bytes32 slot = keccak256(abi.encode(AUCTION_BIDS_AUCTIONEER, auctionId, bidIndex));
        assembly {
            sstore(slot, auctioneer)
        }
    }

    function getAuctionBidsTimestamp_V1(bytes16 auctionId, uint256 bidIndex) public view returns (uint32 time) {
        bytes32 slot = keccak256(abi.encode(AUCTION_BIDS_TIMESTAMP, auctionId, bidIndex));
        assembly {
            time := sload(slot)
        }
        return time;
    }

    function _setAuctionBidsTimestamp_V1(bytes16 auctionId, uint256 bidIndex, uint32 time) internal {
        bytes32 slot = keccak256(abi.encode(AUCTION_BIDS_TIMESTAMP, auctionId, bidIndex));
        assembly {
            sstore(slot, time)
        }
    }

    function getAuctionLastSponsorForBidder_V1(bytes16 auctionId, address bidder) public view returns (address value) {
        bytes32 slot = keccak256(abi.encode(AUCTION_LAST_SPONSOR_FOR_BIDDER, auctionId, bidder));
        assembly {
            value := sload(slot)
        }
        return value;
    }

    function _setAuctionLastSponsorForBidder_V1(bytes16 auctionId, address bidder, address value) internal {
        bytes32 slot = keccak256(abi.encode(AUCTION_LAST_SPONSOR_FOR_BIDDER, auctionId, bidder));
        assembly {
            sstore(slot, value)
        }
    }

    function getAuctionCurrentLeader_V1(bytes16 auctionId) public view returns (address user) {
        bytes32 slot = keccak256(abi.encode(AUCTION_CURRENT_LEADER, auctionId));
        assembly {
            user := sload(slot)
        }
        return user;
    }

    function _setAuctionCurrentLeader_V1(bytes16 auctionId, address user) internal {
        bytes32 slot = keccak256(abi.encode(AUCTION_CURRENT_LEADER, auctionId));
        assembly {
            sstore(slot, user)
        }
    }

    function getAuctionMinimalBid_V1(bytes16 auctionId) public view returns (uint256 value) {
        uint256 currentAmount = getAuctionCurrentAmount_V1(auctionId);
        if (currentAmount > 0) {
            return currentAmount.add(getAuctionBidIncrement_V1(auctionId));
        }

        return getAuctionCurrencyAmount_V1(auctionId);
    }

    /// config layout :
    /// tokensCount : uint16 (32, 2)
    /// currency contract address : address (34, 20)
    /// currency id : bytes32 (54, 32)
    /// currency start amount : uint256 (86, 32)
    /// time begin : uint32 (118, 4)
    /// time end : uint32 (122, 4)
    /// antisnipping trigger period : uint24 (126, 3)
    /// antisnipping duration : uint16 (129, 2)
    /// bid increment : uint256 (131, 32)
    /// sponsor : address (163, 20)
    /// reward master : uint8 (183, 1)
    /// reward auction sponsor : uint8 (184, 1)
    /// reward bid auctioneer : uint8 (185, 1)
    /// reward bid sponsor : uint8 (186, 1)
    /// reward last bid sponsor : uint8 (187, 1)
    /// for 0..tokensCount :
    ///     contractAddress : address (20)
    ///     id : bytes32 (32)
    ///     amount: uint256 (32)
    function createEnglishAuction_V1(bytes16 auctionId, bytes memory config) public {
        require(getAuctionType_V1(auctionId) == 0, "AUCTION_ALREADY_EXIST");
        require(config.length >= 32, "EMPTY_AUCTION_CONFIG");
        uint16 configOffset = 0;

        _setAuctionType_V1(auctionId, AUCTION_TYPE_ENGLISH);
        _setAuctionSeller_V1(auctionId, msg.sender);

        configOffset = _registerAuctionTokens_V1(auctionId, configOffset, config);
        configOffset = _registerAuctionCurrency_V1(auctionId, configOffset, config);
        configOffset = _registerAuctionTimes_V1(auctionId, configOffset, config);
        configOffset = _registerAuctionAntiSnipping_V1(auctionId, configOffset, config);
        configOffset = _registerAuctionBidIncrement_V1(auctionId, configOffset, config);
        configOffset = _registerAuctionSponsor_V1(auctionId, configOffset, config);

        configOffset = _registerAuctionRewards_V1(auctionId, configOffset, config);

        require( getAuctionTimeBegin_V1(auctionId) < getAuctionTimeEnd_V1(auctionId) || block.timestamp < getAuctionTimeEnd_V1(auctionId), "INVALID_DATE_AT_CONTRACT_CREATION");

        require(getAuctionCurrencyAmount_V1(auctionId) > 0, 'INVALID_START_AMOUNT_AT_CONTRACT_CREATION');

        require(config.length == configOffset, "INVALID_AUCTION_CONFIG");
        require(config.length == 156 + getAuctionTokensCount_V1(auctionId) * 84, "INVALID_AUCTION_CONFIG");

        _emitLogAuctionCreateEnglish_V1(auctionId);
    }

    function _emitLogAuctionCreateEnglish_V1(bytes16 auctionId) internal {

        emit LogAuctionCreateEnglish_V1(
            auctionId,
            getAuctionCurrencyContractAddress_V1(auctionId),
            getAuctionCurrencyId_V1(auctionId),
            getAuctionCurrencyAmount_V1(auctionId),
            getAuctionTimeBegin_V1(auctionId),
            getAuctionTimeEnd_V1(auctionId)
        );

        emit LogAuctionCreateEnglishBidding_V1(
            auctionId,
            getAuctionAntiSnippingTrigger_V1(auctionId),
            getAuctionAntiSnippingDuration_V1(auctionId),
            getAuctionBidIncrement_V1(auctionId)
        );

        emit LogAuctionCreateEnglishReward_V1(
            auctionId,
            getAuctionSponsor_V1(auctionId),
            getAuctionRewardCommunity_V1(auctionId),
            getAuctionRewardAuctionSponsor_V1(auctionId),
            getAuctionRewardBidSponsor_V1(auctionId),
            getAuctionRewardBidAuctioneer_V1(auctionId),
            getAuctionRewardLastBidSponsor_V1(auctionId)
        );

        uint16 auctionTokensCount = getAuctionTokensCount_V1(auctionId);

        address[] memory tokenContractAddress = new address[](auctionTokensCount);
        uint256[] memory tokenId = new uint256[](auctionTokensCount);
        uint256[] memory tokenAmount = new uint256[](auctionTokensCount);

        for(uint256 tokenIndex = 0; tokenIndex < auctionTokensCount; tokenIndex++)
        {
            Token memory auctionToken = _getAuctionToken_V1(auctionId, tokenIndex);

            tokenContractAddress[tokenIndex] = auctionToken.contractAddress;
            tokenId[tokenIndex] = auctionToken.id;
            tokenAmount[tokenIndex] = auctionToken.amount;
        }

        emit LogAuctionCreateEnglishTokens_V1(
            auctionId,
            tokenContractAddress,
            tokenId,
            tokenAmount
        );

    }

    /// @notice internal decode config and register currency
    /// @param auctionId bytes32
    /// @param config bytes
    function _registerAuctionCurrency_V1(bytes16 auctionId, uint16 configOffset, bytes memory config) internal returns (uint16) {
        Token memory token;
        address ca = address(0);
        uint256 id = 0;
        uint256 amount = 0;

        assembly {
            ca := mload(add(config, add(configOffset,20)))
            id := mload(add(config, add(configOffset,52)))
            amount := mload(add(config, add(configOffset,84)))
        }
        require(amount > 0,"AUCTION_TOKEN_AMOUNT_MUST_BE_GREATER_THAN_ZERO");

        token.contractAddress = ca;
        token.id = id;
        token.amount = amount;
        _setAuctionCurrency_V1(auctionId, token);

        return (configOffset + 84);
    }

    function _registerAuctionTimes_V1(bytes16 auctionId, uint16 configOffset, bytes memory config)  internal returns (uint16) {
        uint32 u32;
        assembly {
            u32 := mload(add(config, add(configOffset, 4))) // 118 - (32 - 4)
        }
        _setAuctionTimeBegin_V1(auctionId, u32);

        assembly {
            u32 := mload(add(config, add(configOffset, 8))) // 122 - (32 - 4)
        }
        _setAuctionTimeEnd_V1(auctionId, u32);
        _setAuctionInitialTimeEnd_V1(auctionId, u32);

        return (configOffset + 8);
    }

    function _registerAuctionAntiSnipping_V1(bytes16 auctionId, uint16 configOffset, bytes memory config)  internal returns (uint16) {
        uint24 u24;
        uint16 u16;

        assembly {
            u24 := mload(add(config, add(configOffset, 3)))
        }
        _setAuctionAntiSnippingTrigger_V1(auctionId, u24);

        assembly {
            u16 := mload(add(config, add(configOffset, 5)))
        }
        _setAuctionAntiSnippingDuration_V1(auctionId, u16);

        return (configOffset + 5);
    }

    function _registerAuctionBidIncrement_V1(bytes16 auctionId, uint16 configOffset, bytes memory config) internal returns (uint16) {
        uint256 u256;

        assembly {
            u256 := mload(add(config, add(configOffset,32)))
        }
        _setAuctionBidIncrement_V1(auctionId, u256);

        return (configOffset + 32);
    }

    function _registerAuctionSponsor_V1(bytes16 auctionId, uint16 configOffset, bytes memory config) internal returns (uint16) {
        address a;

        assembly {
            a := mload(add(config, add(configOffset, 20)))
        }
        _setAuctionSponsor(auctionId, a);

        return (configOffset + 20);
    }

    /// @notice internal decode config and register rewards
    /// @param auctionId bytes32
    /// @param config bytes
    function _registerAuctionRewards_V1(bytes16 auctionId, uint16 configOffset, bytes memory config) internal returns (uint16) {

        uint8 r;

        assembly {
            r := mload(add(config, add(configOffset, 1))) // 183 - (32 - 1)
        }

        _setAuctionRewardCommunity_V1(auctionId, r);

        if(r > 0) {

            uint8 totalRewardPercent = 0;

            assembly {
                r := mload(add(config, add(configOffset, 2)))
            }
            totalRewardPercent = totalRewardPercent + r;
            _setAuctionRewardAuctionSponsor_V1(auctionId, r);

            assembly {
                r := mload(add(config, add(configOffset, 3)))
            }
            totalRewardPercent = totalRewardPercent + r;
            _setAuctionRewardBidAuctioneer_V1(auctionId, r);

            assembly {
                r := mload(add(config, add(configOffset, 4)))
            }
            totalRewardPercent = totalRewardPercent + r;
            _setAuctionRewardBidSponsor(auctionId, r);

            assembly {
                r := mload(add(config, add(configOffset, 5)))
            }
            totalRewardPercent = totalRewardPercent + r;
            _setAuctionRewardLastBidSponsor_V1(auctionId, r);

            require (totalRewardPercent == 100, "INVALID_AUCTION_REWARDS_PERCENT");
        }
        return (configOffset + 5);

    }

    function _registerAuctionTokens_V1(bytes16 auctionId, uint16 configOffset, bytes memory config) internal returns (uint16) {
        uint16 tokensCount = 0;
        assembly {
            tokensCount := mload(add(config, add(configOffset, 2)))
        }
        require(tokensCount > 0, "AUCTION_WITHOUT_TOKENS");
        _setAuctionTokensCount_V1(auctionId, tokensCount);
        configOffset = configOffset + 2;

        for (uint16 index = 0; index < tokensCount; ++index) {
            configOffset = _registerAuctionToken_V1(auctionId, configOffset, config, index);
        }

        return configOffset;
    }

    /// @notice internal decode config, register tokens for index, and locked then
    /// @param auctionId bytes32
    /// @param config bytes
    /// @param index uint16 , index of tokens for locks
    function _registerAuctionToken_V1(bytes16 auctionId, uint16 configOffset, bytes memory config, uint16 index) internal returns (uint16) {
        Token memory token;
        address ca = address(0);
        uint256 id = 0;
        uint256 amount = 0;

        assembly {
            ca := mload(add(config, add(configOffset, 20)))
            id := mload(add(config, add(configOffset, 52)))
            amount := mload(add(config, add(configOffset, 84)))
        }
        require(amount > 0,"AUCTION_TOKEN_AMOUNT_MUST_BE_GREATER_THAN_ZERO");

        token.contractAddress = ca;
        token.id = id;
        token.amount = amount;

        // Lock token on delegate
        _delegatedLockDeposit_V1(
            msg.sender,
            token.contractAddress,
            token.id,
            token.amount,
            uint256(uint128(auctionId))
        );

        _setAuctionToken_V1(auctionId, index, token);

        return (configOffset + 84);
    }

    /// @notice bid for auction
    /// @param auctionId bytes32
    /// @param amount uint256 of bid
    /// @param sponsor address of sponsor
    /// @param auctioneer address of auctioneer
    function bidEnglishAuction_V1(
        bytes16 auctionId,
        uint256 amount,
        address sponsor,
        address auctioneer
    ) public {

        require(getAuctionType_V1(auctionId) == AUCTION_TYPE_ENGLISH, "AUCTION_NOT_EXIST");

        require(block.timestamp >= getAuctionTimeBegin_V1(auctionId), "AUCTION_IS_NOT_STARTED_YET");

        require(block.timestamp <= getAuctionTimeEnd_V1(auctionId), "AUCTION_IS_ALREADY_CLOSED");

        require(msg.sender != getAuctionSeller_V1(auctionId), "AUCTION_OWNER_CAN_NOT_BID");

        require(sponsor != address(0), "BID_SPONSOR_REQUIRED");

        require(amount >= getAuctionMinimalBid_V1(auctionId), "BIDDING AMOUNT_TOO_LOW");

        address bidder = msg.sender;

        // unlock previous  leader
        if(getAuctionCurrentLeader_V1(auctionId) != address(0))
        {
            _delegatedUnLockDeposit_V1(
                getAuctionCurrentLeader_V1(auctionId),
                getAuctionCurrencyContractAddress_V1(auctionId),
                getAuctionCurrencyId_V1(auctionId),
                getAuctionCurrentAmount_V1(auctionId),
                uint256(uint128(auctionId))
            );
        }

        // Lock new currency amount for bidder
        _delegatedLockDeposit_V1(
            bidder,
            getAuctionCurrencyContractAddress_V1(auctionId),
            getAuctionCurrencyId_V1(auctionId),
            amount,
            uint256(uint128(auctionId))
        );

        // get next index for bidding history and rewards
        uint256 bidIndex = _addAuctionNewBid_V1(auctionId) -1; // index is number of bid - 1

        _setAuctionBidsUser_V1(auctionId, bidIndex, bidder);
        _setAuctionBidsAmount_V1(auctionId, bidIndex, amount);
        _setAuctionBidsSponsor_V1(auctionId, bidIndex, sponsor);
        _setAuctionBidsAuctioneer_V1(auctionId, bidIndex, auctioneer);
        _setAuctionBidsTimestamp_V1(auctionId, bidIndex, uint32(block.timestamp));

        _setAuctionLastSponsorForBidder_V1(auctionId, bidder, sponsor);

        _setAuctionCurrentAmount_V1(auctionId, amount);
        _setAuctionCurrentLeader_V1(auctionId, bidder);

        emit LogBid_V1(
            auctionId,
            bidIndex,
            bidder,
            amount,
            getAuctionMinimalBid_V1(auctionId),
            sponsor,
            auctioneer
        );

        // Anti snipping
        if (block.timestamp > getAuctionTimeEnd_V1(auctionId) - getAuctionAntiSnippingTrigger_V1(auctionId)) {
            _setAuctionTimeEnd_V1(auctionId, uint32(block.timestamp + getAuctionAntiSnippingDuration_V1(auctionId)));

            emit LogAntiSnippingTriggered_V1(auctionId, getAuctionTimeEnd_V1(auctionId));
        }
    }


    /// @notice close an auction
    /// @param auctionId bytes32
    function endEnglishAuction_V1(bytes16 auctionId) public {

        require(getAuctionType_V1(auctionId) == AUCTION_TYPE_ENGLISH, "AUCTION_NOT_EXIST");
        require(block.timestamp > getAuctionTimeEnd_V1(auctionId), "AUCTION_IS_NOT_CLOSED_YET");
        require(!getAuctionEnded_V1(auctionId), "AUCTION_IS_ALREADY_ENDED");

        _setAuctionEnded_V1(auctionId, true);

        address seller = getAuctionSeller_V1(auctionId);
        address winner = getAuctionCurrentLeader_V1(auctionId);
        uint256 currentAmount = getAuctionCurrentAmount_V1(auctionId);

        if(winner == address(0)) {
            // if no bid for this auction, send back tokens to seller
            _transferTokens_V1(auctionId, seller, seller);
        }else {
            // if we have at least one bid

            // if we have community rewards, set rewards amount
            if (getAuctionRewardCommunity_V1(auctionId) > 0) {

                _setRewardsAmount_V1(auctionId, currentAmount);
                _setBidRewards_V1(auctionId);
            }

            _setAmountForSeller_V1(auctionId, currentAmount);

            _transferTokens_V1(auctionId, seller, winner);
        }

        emit LogAuctionClosed_V1(
            auctionId,
            winner,
            currentAmount,
            getAuctionTimeEnd_V1(auctionId)
        );

    }

    /// @notice internal set bids rewards
    /// @param auctionId bytes32
    function _setBidRewards_V1(bytes16 auctionId) internal {

        uint _bidSponsorsLength = getAuctionBidCount_V1(auctionId);

        // get time leading for sponsor
        uint256 bidRewardsSponsorLength;
        address[] memory bidRewardsSponsorAddress;
        uint32[] memory bidRewardsSponsorTimeLeading;
        uint256 bidRewardsAuctioneerLength;
        address[] memory bidRewardsAuctioneerAddress;
        uint32[] memory bidRewardsAuctioneerTimeLeading;

        bidRewardsSponsorAddress = new address[](_bidSponsorsLength);
        bidRewardsSponsorTimeLeading = new uint32[](_bidSponsorsLength);

        bidRewardsAuctioneerAddress = new address[](_bidSponsorsLength);
        bidRewardsAuctioneerTimeLeading = new uint32[](_bidSponsorsLength);

        // if only one bid
        if (_bidSponsorsLength == 1) {

            bidRewardsSponsorLength = 1;
            bidRewardsAuctioneerLength = 1;

            bidRewardsSponsorAddress[0] = getAuctionBidsSponsor_V1(auctionId,0);
            bidRewardsSponsorTimeLeading[0] = uint32(1);

            bidRewardsAuctioneerAddress[0] = getAuctionBidsAuctioneer_V1(auctionId,0);
            bidRewardsAuctioneerTimeLeading[0] = uint32(1);
        }
        else {

            bool _found;
            uint _bidSponsorsIndex;
            uint _bidRewardsIndex;

            bidRewardsSponsorLength = 0;
            bidRewardsAuctioneerLength = 0;

            /// @dev loop of all bid sponsor
            for (_bidSponsorsIndex = 0; _bidSponsorsIndex < _bidSponsorsLength - 1; _bidSponsorsIndex++) {

                _found = false;

                for (_bidRewardsIndex = 0; _bidRewardsIndex < bidRewardsSponsorLength; _bidRewardsIndex++) {
                    if (bidRewardsSponsorAddress[_bidRewardsIndex] == getAuctionBidsSponsor_V1(auctionId,_bidSponsorsIndex)) {
                        bidRewardsAuctioneerTimeLeading[_bidRewardsIndex] = bidRewardsAuctioneerTimeLeading[_bidRewardsIndex].add(
                            getAuctionBidsTimestamp_V1(auctionId,_bidSponsorsIndex + 1).sub(
                                getAuctionBidsTimestamp_V1(auctionId,_bidSponsorsIndex)
                            )
                        );
                        _found = true;
                        continue;
                    }

                }

                if (!_found) {
                    bidRewardsSponsorAddress[bidRewardsSponsorLength] = getAuctionBidsSponsor_V1(auctionId,_bidSponsorsIndex);
                    bidRewardsSponsorTimeLeading[bidRewardsSponsorLength] = getAuctionBidsTimestamp_V1(auctionId,_bidSponsorsIndex + 1).sub(
                        getAuctionBidsTimestamp_V1(auctionId,_bidSponsorsIndex));
                    bidRewardsSponsorLength++;

                }

                /// @dev search bid auctioneer
                _found = false;

                for (_bidRewardsIndex = 0; _bidRewardsIndex < bidRewardsAuctioneerLength; _bidRewardsIndex++) {
                    if (bidRewardsAuctioneerAddress[_bidRewardsIndex] == getAuctionBidsAuctioneer_V1(auctionId,_bidSponsorsIndex)) {
                        bidRewardsAuctioneerTimeLeading[_bidRewardsIndex] = bidRewardsAuctioneerTimeLeading[_bidRewardsIndex].add(
                            getAuctionBidsTimestamp_V1(auctionId,_bidSponsorsIndex + 1).sub(
                                getAuctionBidsTimestamp_V1(auctionId,_bidSponsorsIndex)
                            )
                        );
                        _found = true;
                        continue;

                    }
                }

                if (!_found && getAuctionBidsAuctioneer_V1(auctionId,_bidSponsorsIndex) != address(
                    0
                )) {
                    bidRewardsAuctioneerAddress[bidRewardsAuctioneerLength] = getAuctionBidsAuctioneer_V1(auctionId,_bidSponsorsIndex);
                    bidRewardsAuctioneerTimeLeading[bidRewardsAuctioneerLength] = getAuctionBidsTimestamp_V1(auctionId,_bidSponsorsIndex + 1).sub(
                        getAuctionBidsTimestamp_V1(auctionId,_bidSponsorsIndex));
                    bidRewardsAuctioneerLength++;
                }

            }

            /// @dev last bid to end
            _found = false;

            /// @dev search bid sponsor
            for (_bidRewardsIndex = 0; _bidRewardsIndex < bidRewardsSponsorLength; _bidRewardsIndex++) {
                if (bidRewardsSponsorAddress[_bidRewardsIndex] == getAuctionBidsSponsor_V1(auctionId,_bidSponsorsIndex)) {
                    bidRewardsSponsorTimeLeading[_bidRewardsIndex] = bidRewardsSponsorTimeLeading[_bidRewardsIndex].add(
                        getAuctionTimeEnd_V1(auctionId).sub(
                            getAuctionBidsTimestamp_V1(auctionId,_bidSponsorsIndex - 1)
                        )
                    );
                    _found = true;
                    continue;
                }
            }

            if (!_found) {

                bidRewardsSponsorAddress[bidRewardsSponsorLength] = getAuctionBidsSponsor_V1(auctionId,_bidSponsorsIndex);
                bidRewardsSponsorTimeLeading[bidRewardsSponsorLength] = getAuctionTimeEnd_V1(auctionId).sub(
                    getAuctionBidsTimestamp_V1(auctionId,_bidSponsorsIndex)
                );
                bidRewardsSponsorLength++;
            }

            /// @dev search bid auctioneer
            for (_bidRewardsIndex = 0; _bidRewardsIndex < bidRewardsAuctioneerLength; _bidRewardsIndex++) {
                if (bidRewardsAuctioneerAddress[_bidRewardsIndex] == getAuctionBidsAuctioneer_V1(auctionId,_bidSponsorsIndex)) {
                    bidRewardsAuctioneerTimeLeading[_bidRewardsIndex] = bidRewardsAuctioneerTimeLeading[_bidRewardsIndex].add(
                        getAuctionTimeEnd_V1(auctionId).sub(
                            getAuctionBidsTimestamp_V1(auctionId,_bidSponsorsIndex)
                        )
                    );
                    _found = true;
                    continue;
                }
            }

            if (!_found && getAuctionBidsAuctioneer_V1(auctionId,_bidSponsorsIndex) != address(
                0
            )) {
                bidRewardsAuctioneerAddress[bidRewardsAuctioneerLength] = getAuctionBidsAuctioneer_V1(auctionId,_bidSponsorsIndex);
                bidRewardsAuctioneerTimeLeading[bidRewardsAuctioneerLength] = getAuctionTimeEnd_V1(auctionId).sub(
                    getAuctionBidsTimestamp_V1(auctionId,_bidSponsorsIndex)
                );
                bidRewardsAuctioneerLength++;
            }
        }
        // set bid rewards for sponsor
        _setBidRewardsSponsorAmount_V1(auctionId, bidRewardsSponsorLength, bidRewardsSponsorAddress, bidRewardsSponsorTimeLeading);

        // set bid rewards for auctioneer
        _setBidRewardsAuctioneerAmount_V1(auctionId, bidRewardsAuctioneerLength, bidRewardsAuctioneerAddress, bidRewardsAuctioneerTimeLeading);
    }

    /// @notice internal set bid sponsor rewards amount from time leading
    /// @param auctionId bytes32
    /// @param bidRewardsSponsorLength uint256
    /// @param bidRewardsSponsorAddress address[]
    /// @param bidRewardsSponsorTimeLeading uint32[]
    function _setBidRewardsSponsorAmount_V1(
        bytes16 auctionId,
        uint256 bidRewardsSponsorLength,
        address[] memory bidRewardsSponsorAddress,
        uint32[] memory bidRewardsSponsorTimeLeading
    ) internal {
        uint _bidRewardsIndex;

        uint256 _rewardBidSponsorTimeLeadingSum;

        /// @dev if number of auctioneer rewards greater then zero
        if (bidRewardsSponsorLength > 0) {

            Token memory currency = _getAuctionCurrency_V1(auctionId);
            address currentLeader = getAuctionCurrentLeader_V1(auctionId);

            for (_bidRewardsIndex = 0; _bidRewardsIndex < bidRewardsSponsorLength; _bidRewardsIndex++) {
                _rewardBidSponsorTimeLeadingSum = _rewardBidSponsorTimeLeadingSum.add(
                    uint256(bidRewardsSponsorTimeLeading[_bidRewardsIndex])
                );
            }

            /// @dev distribute sponsor reward amount
            uint _rewardBidSponsorAmount;
            uint256 rewardBidSponsorTotalAmount = getAuctionRewardBidSponsorAmount_V1(auctionId);


            for (_bidRewardsIndex = 0; _bidRewardsIndex < bidRewardsSponsorLength; _bidRewardsIndex++) {
                _rewardBidSponsorAmount = rewardBidSponsorTotalAmount.mul(
                    bidRewardsSponsorTimeLeading[_bidRewardsIndex]
                ).div(_rewardBidSponsorTimeLeadingSum);

                if (_rewardBidSponsorAmount > 0) {

                    _delegatedTransferDepotLocked_V1(
                        uint256(uint128(auctionId)),
                        currentLeader,
                        bidRewardsSponsorAddress[_bidRewardsIndex],
                        currency.contractAddress,
                        currency.id,
                        _rewardBidSponsorAmount,
                        false,
                        abi.encodePacked(AUCTION_TRANSFER_REWARDS_BID_SPONSOR)
                    );
                }
            }
        }
    }

    /// @notice internal set bid auctioneer rewards amount from time leading
    /// @param auctionId bytes32
    /// @param bidRewardsAuctioneerLength uint256
    /// @param bidRewardsAuctioneerAddress address[]
    /// @param bidRewardsAuctioneerTimeLeading uint32[]
    function _setBidRewardsAuctioneerAmount_V1(
        bytes16 auctionId,
        uint256 bidRewardsAuctioneerLength,
        address[] memory bidRewardsAuctioneerAddress,
        uint32[] memory bidRewardsAuctioneerTimeLeading
    ) internal {
        uint _bidRewardsIndex;

        uint256 _rewardBidAuctioneerTimeLeadingSum;

        // if number of auctioneer rewards greater then zero
        if (bidRewardsAuctioneerLength > 0) {

            Token memory currency = _getAuctionCurrency_V1(auctionId);

            address currentLeader = getAuctionCurrentLeader_V1(auctionId);

            // sum of auctioneer time leading
            for (_bidRewardsIndex = 0; _bidRewardsIndex < bidRewardsAuctioneerLength; _bidRewardsIndex++) {
                _rewardBidAuctioneerTimeLeadingSum = _rewardBidAuctioneerTimeLeadingSum.add(
                    uint256(bidRewardsAuctioneerTimeLeading[_bidRewardsIndex])
                );
            }

            // distribute auctioneer reward amount
            uint256 _rewardBidAuctioneerAmount;
            uint256 rewardBidAuctioneerTotalAmount = getAuctionRewardBidAuctioneerAmount_V1(auctionId);

            for (_bidRewardsIndex = 0; _bidRewardsIndex < bidRewardsAuctioneerLength; _bidRewardsIndex++) {

                _rewardBidAuctioneerAmount = rewardBidAuctioneerTotalAmount.mul(
                    bidRewardsAuctioneerTimeLeading[_bidRewardsIndex]
                ).div(_rewardBidAuctioneerTimeLeadingSum);

                if (_rewardBidAuctioneerAmount > 0) {

                    _delegatedTransferDepotLocked_V1(
                        uint256(uint128(auctionId)),
                        currentLeader,
                        bidRewardsAuctioneerAddress[_bidRewardsIndex],
                        currency.contractAddress,
                        currency.id,
                        _rewardBidAuctioneerAmount,
                        false,
                        abi.encodePacked(AUCTION_TRANSFER_REWARDS_BID_AUCTIONEER)
                    );
                }
            }
        }
    }

    /// @notice internal set amount from reward's percent
    /// @param auctionId bytes32
    function _setRewardsAmount_V1(bytes16 auctionId, uint256 currentAmount) internal {

        // calculate amount of community rewards
        uint256 rewardCommunityAmount = currentAmount.mul(uint256(getAuctionRewardCommunity_V1(auctionId))).div(100);
        _setAuctionRewardCommunityAmount_V1(auctionId, rewardCommunityAmount);

        if(rewardCommunityAmount > 0)
        {

            Token memory currency = _getAuctionCurrency_V1(auctionId);
            address currentLeader = getAuctionCurrentLeader_V1(auctionId);

            // calculate amount of auction sponsor rewards
            uint256 rewardAuctionSponsorAmount = rewardCommunityAmount.mul(uint256(getAuctionRewardAuctionSponsor_V1(auctionId))).div(100);
            _setAuctionRewardAuctionSponsorAmount_V1(auctionId, rewardAuctionSponsorAmount);

            if(rewardAuctionSponsorAmount > 0)
            {
                // transfer auction's sponsor rewards
                _delegatedTransferDepotLocked_V1(
                    uint256(uint128(auctionId)),
                    currentLeader,
                    getAuctionSponsor_V1(auctionId),
                    currency.contractAddress,
                    currency.id,
                    rewardAuctionSponsorAmount,
                    false,
                    abi.encodePacked(AUCTION_TRANSFER_REWARDS_AUCTION_SPONSOR)
                );
            }
            // calculate amount of last bid sponsor rewards
            uint256 rewardLastBidSponsorAmount = rewardCommunityAmount.mul(uint256(getAuctionRewardLastBidSponsor_V1(auctionId))).div(100);
            _setAuctionRewardLastBidSponsorAmount_V1(auctionId, rewardLastBidSponsorAmount);

            if(rewardLastBidSponsorAmount > 0)
            {
                // transfer last bid sponsor rewards
                _delegatedTransferDepotLocked_V1(
                    uint256(uint128(auctionId)),
                    currentLeader,
                    getAuctionLastSponsorForBidder_V1(auctionId, currentLeader),
                    currency.contractAddress,
                    currency.id,
                    rewardLastBidSponsorAmount,
                    false,
                    abi.encodePacked(AUCTION_TRANSFER_REWARDS_LAST_BID_SPONSOR)
                );
            }

            // calculate amount for all bid's sponsor rewards
            uint256 rewardBidSponsorAmount = rewardCommunityAmount.mul(uint256(getAuctionRewardBidSponsor_V1(auctionId))).div(100);
            _setAuctionRewardBidSponsorAmount_V1(auctionId, rewardBidSponsorAmount);

            // calculate amount of last bid's auctioneer rewards
            uint256 rewardBidAuctioneerAmount = rewardCommunityAmount.mul(uint256(getAuctionRewardBidAuctioneer_V1(auctionId))).div(100);
            _setAuctionRewardBidAuctioneerAmount_V1(auctionId, rewardBidAuctioneerAmount);

        }
    }

    /// @notice internal set amount for seller
    /// @param auctionId bytes32
    function _setAmountForSeller_V1(bytes16 auctionId, uint256 currentAmount) internal {

        // get current amount, do nothing if no bid
        if (currentAmount == 0) {
            return;
        }

        Token memory currency = _getAuctionCurrency_V1(auctionId);

        // Get the balance of winner after sended all rewards
        uint256 sellerAmount = _delegatedGetBalanceLockedERC1155_V1(
            getAuctionCurrentLeader_V1(auctionId),
            currency.contractAddress,
            currency.id,
            uint256(uint128(auctionId))
        );

        // Verify if amount for seller is greater or egual than last bidder amount sub community rewards amount
        require(sellerAmount >= currentAmount.sub(getAuctionRewardCommunityAmount_V1(auctionId)), "seller amount is too lower");

        _setAuctionSellerAmount_V1(auctionId, sellerAmount);

        if(sellerAmount > 0)
        {
            // transfer seller's amount
            _delegatedTransferDepotLocked_V1(
                uint256(uint128(auctionId)),
                getAuctionCurrentLeader_V1(auctionId),
                getAuctionSeller_V1(auctionId),
                currency.contractAddress,
                currency.id,
                sellerAmount,
                false,
                abi.encodePacked(AUCTION_TRANSFER_AMOUNT_TO_THE_SELLER)
            );
        }

    }

    /// @notice internal transfer all tokens engaged
    /// @param auctionId bytes32
    /// @param from addresse of seller
    /// @param to addresse of winner, or seller if no bid
    function _transferTokens_V1(bytes16 auctionId, address from, address to) internal {

        // get number of token
        uint16 numberOfTokens = getAuctionTokensCount_V1(auctionId);

        // for all tokens engaged
        for(uint16 index = 0 ; index < numberOfTokens; index++){

            Token memory auctionToken = _getAuctionToken_V1(auctionId, index);

            // transfer token
            _delegatedTransferDepotLocked_V1(
                uint256(uint128(auctionId)),
                from,
                to,
                auctionToken.contractAddress,
                auctionToken.id,
                auctionToken.amount,
                false,
                abi.encodePacked(AUCTION_TRANSFER_TOKENS)
            );
        }
    }

    /// @notice internal lock deposit
    /// @param from address of owner
    /// @param tokenContractAddress address of token contract
    /// @param tokenId uint256 id of token
    /// @param amount uint256 number of token
    /// @param lockedFor uin256 identity of locked requested (auctionId)
    function _delegatedLockDeposit_V1(
        address from,
        address tokenContractAddress,
        uint256 tokenId,
        uint256 amount,
        uint256 lockedFor
    ) internal{
        _callInternalDelegated_V1(
            abi.encodeWithSelector(
                bytes4(keccak256("internalLockDeposit_V2(address,address,uint256,uint256,uint256)")),
                from,
                tokenContractAddress,
                tokenId,
                amount,
                lockedFor
            ),
            address(0)
        );
    }


    /// @notice internal unlock deposit
    /// @param from address of owner
    /// @param tokenContractAddress address of token contract
    /// @param tokenId uint256 id of token
    /// @param amount uint256 number of token
    /// @param lockedFor uin256 identity of locked requested (auctionId)
    function _delegatedUnLockDeposit_V1(
        address from,
        address tokenContractAddress,
        uint256 tokenId,
        uint256 amount,
        uint256 lockedFor
    ) internal{

        _callInternalDelegated_V1(
            abi.encodeWithSelector(
                bytes4(keccak256("internalUnLockDeposit_V2(address,address,uint256,uint256,uint256)")),
                from,
                tokenContractAddress,
                tokenId,
                amount,
                lockedFor
            ),
            address(0)
        );
    }

    /// @notice internal transfer deposit locked
    /// @param lockedFor uin256 identity of locked requested (auctionId)
    /// @param from address of owner
    /// @param to address of receiver
    /// @param tokenContractAddress address of token contract
    /// @param tokenId uint256 id of token
    /// @param amount uint256 number of token
    /// @param keepLock bool , true if the transfer want to keep tocken locked
    /// @param data bytes additional data for transfer
    function _delegatedTransferDepotLocked_V1(
        uint256 lockedFor,
        address from,
        address to,
        address tokenContractAddress,
        uint256 tokenId,
        uint256 amount,
        bool keepLock,
        bytes memory data
    ) internal{
        _callInternalDelegated_V1(
            abi.encodeWithSelector(
                bytes4(keccak256("internalTransferDepotLocked_V2(uint256,address,address,address,uint256,uint256,bool,bytes)")),
                lockedFor,
                from,
                to,
                tokenContractAddress,
                tokenId,
                amount,
                keepLock,
                data
            ),
            address(0)
        );
    }

    /// @notice internal get balance locked
    /// @param from address of owner
    /// @param tokenContractAddress address of token contract
    /// @param tokenId uint256 id of token
    /// @param lockedFor uin256 identity of locked requested (auctionId)
    /// @return value uint256 balance of
    function _delegatedGetBalanceLockedERC1155_V1(
        address from,
        address tokenContractAddress,
        uint256 tokenId,
        uint256 lockedFor
    ) internal returns (uint256 value){
        uint returnPtr;
        uint returnSize;

        (returnPtr, returnSize) = _callDelegated_V1(
            abi.encodeWithSelector(
                bytes4(keccak256("getBalanceLockedERC1155_V1(address,address,uint256,uint256)")),
                from,
                tokenContractAddress,
                tokenId,
                lockedFor
            ),
            address(0)
        );

        assembly {
            value := mload(returnPtr)
        }

        return value;
    }
}
