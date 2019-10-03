pragma solidity ^0.5.4;

import "./AuctionityStorage1.sol";
import "../CommonContract/AuctionityLibrary_V1.sol";
import "../CommonContract/AuctionityChainId_V1.sol";
import "../CommonContract/AuctionityLibraryDecodeRawTx_V1.sol";
import "../CommonContract/SafeMath.sol";

/// @title Auctionity Treasurer
contract AuctionityTreasurer_V1 is AuctionityStorage1, AuctionityLibrary_V1, AuctionityChainId_V1 {
    using SafeMath for uint256;


    // For previous compatibility
    event LogAddDepotEth(address user, uint256 amount, uint256 totalAmount, bytes32 hashTransactionDeposit);
    event LogAddRewardDepotEth(address user, uint256 amount, uint256 totalAmount, bytes32 hashTransactionDeposit);
    event LogWithdrawal(address user, uint256 amount);
    event LogSetWithdrawalVoucher(address user, uint256 amount, bytes voucher);
    event LogWithdrawalVoucherHaveBeenRemoved(address user, bytes32 voucherHash);
    event LogNewDepotLock(address user, uint256 amount);
    event LogLockDepositRefund(address user, uint256 amount);
    event LogEndorse(address auctionAddress, address user, uint256 amount);



    event LogAddDepot_V1(
        address user,
        address tokenContractAddress,
        uint256 tokenId,
        uint256 amount,
        uint256 totalAmount,
        bytes32 transactionHashDeposit
    );
    event LogAddRewardDepot_V1(
        address user,
        address tokenContractAddress,
        uint256 tokenId,
        uint256 amount,
        uint256 totalAmount,
        bytes32 hashTransactionDeposit
    );
    event LogWithdrawal_V1(
        address user,
        address tokenContractAddress,
        uint256 tokenId,
        uint256 amount
    );
    event LogSetWithdrawalVoucher_V1(
        address user,
        uint256 amount,
        bytes voucher
    );
    event LogWithdrawalVoucherHaveBeenRemoved_V1(
        address user,
        bytes32 voucherHash
    );
    event LogNewDepotLock_V1(
        address user,
        address tokenContractAddress,
        uint256 tokenId,
        uint256 amount,
        uint256 auctionId
    );
    event LogRefundDepotLock_V1(
        address user,
        address tokenContractAddress,
        uint256 tokenId,
        uint256 amount,
        uint256 auctionId
    );
    event LogEndorse_V1(
        address user,
        address tokenContractAddress,
        uint256 tokenId,
        uint256 amount,
        uint256 auctionId
    );


    modifier isUniqueTransactionHashDeposit_V1(
        bytes32 _transactionHashDeposit
    ) {
        require(
            !depositTransactionHash[_transactionHashDeposit],
            "Transaction Hash is already exist"
        );

        depositTransactionHash[_transactionHashDeposit] = true;

        _;
    }

    /// @notice receive DepotEth
    /// @dev Receive deposit of eth from livenet through oracle
    /// @param _user address
    /// @param _amount uint256
    /// @param _transactionHashDeposit bytes32 : hash of transaction from livenet, for anti replay
    /// @return bool
    function receiveDepotEth_V1(
        address _user,
        uint256 _amount,
        bytes32 _transactionHashDeposit
    )
        public
        delegatedSendIsOracle_V1
        isUniqueTransactionHashDeposit_V1(_transactionHashDeposit)
        returns (bool)
    {
        _addDepotEth_V1(_user, _amount);

        // For previous compatibility
        emit LogAddDepotEth(
            _user,
            _amount,
            getBalanceEth_V1(_user),
            _transactionHashDeposit);

        emit LogAddDepot_V1(
            _user,
            address(0),
            uint256(0),
            _amount,
            getBalanceEth_V1(_user),
            _transactionHashDeposit
        );

        return true;
    }

    /// @notice receive reward DepotEth
    /// @dev Receive reward deposit of eth from livenet through oracle
    /// @param _user address
    /// @param _amount uint256
    /// @param _transactionHashDeposit bytes32 : hash of transaction from livenet, for history only
    /// @return bool
    function receiveRewardDepotEth_V1(
        address _user,
        uint256 _amount,
        bytes32 _transactionHashDeposit
    ) public delegatedSendIsOracle_V1 returns (bool) {
        _addDepotEth_V1(_user, _amount);

        // For previous compatibility
        emit LogAddRewardDepotEth(
            _user,
            _amount,
            getBalanceEth_V1(_user),
                _transactionHashDeposit);

        emit LogAddRewardDepot_V1(
            _user,
            address(0),
            uint256(0),
            _amount,
            getBalanceEth_V1(_user),
            _transactionHashDeposit
        );

        return true;
    }

    /// @notice receive DepotErc20
    /// @dev Receive deposit of ERC20 from livenet through oracle
    /// @param _user address
    /// @param _tokenContractAddress address : ERC20 smart contract
    /// @param _amount uint256
    /// @param _transactionHashDeposit bytes32 : hash of transaction from livenet, for anti replay
    /// @return bool
    function receiveDepotERC20_V1(
        address _user,
        address _tokenContractAddress,
        uint256 _amount,
        bytes32 _transactionHashDeposit
    )
        public
        delegatedSendIsOracle_V1
        isUniqueTransactionHashDeposit_V1(_transactionHashDeposit)
        returns (bool)
    {
        _addDepotERC20_V1(_user, _tokenContractAddress, _amount);

        emit LogAddDepot_V1(
            _user,
            _tokenContractAddress,
            uint256(0),
            _amount,
            getBalanceERC20_V1(_user, _tokenContractAddress),
            _transactionHashDeposit
        );

        return true;
    }

    /// @notice receive reward DepotErc20
    /// @dev Receive reward deposit of ERC20 from livenet through oracle
    /// @param _user address
    /// @param _tokenContractAddress address : ERC20 smart contract
    /// @param _amount uint256
    /// @param _transactionHashDeposit bytes32 : hash of transaction from livenet, history only
    /// @return bool
    function receiveRewardDepotERC20_V1(
        address _user,
        address _tokenContractAddress,
        uint256 _amount,
        bytes32 _transactionHashDeposit
    ) public delegatedSendIsOracle_V1 returns (bool) {
        _addDepotERC20_V1(_user, _tokenContractAddress, _amount);

        emit LogAddRewardDepot_V1(
            _user,
            _tokenContractAddress,
            uint256(0),
            _amount,
            getBalanceERC20_V1(_user, _tokenContractAddress),
            _transactionHashDeposit
        );

        return true;
    }

    /// @notice receive DepotErc721
    /// @dev Receive deposit of ERC721 from livenet through oracle
    /// @param _user address
    /// @param _tokenContractAddress address : ERC721 smart contract
    /// @param _tokenId uint256 : tokenId of ERC721
    /// @param _transactionHashDeposit bytes32 : hash of transaction from livenet, for anti replay
    /// @return bool
    function receiveDepotERC721_V1(
        address _user,
        address _tokenContractAddress,
        uint256 _tokenId,
        bytes32 _transactionHashDeposit
    )
        public
        delegatedSendIsOracle_V1
        isUniqueTransactionHashDeposit_V1(_transactionHashDeposit)
        returns (bool)
    {
        _addDepotERC721_V1(_user, _tokenContractAddress, _tokenId);

        emit LogAddDepot_V1(
            _user,
            _tokenContractAddress,
            _tokenId,
            1,
            getBalanceERC721_V1(_user, _tokenContractAddress, _tokenId),
            _transactionHashDeposit
        );

        return true;
    }

    /// @notice receive DepotErc1155
    /// @dev Receive deposit of ERC1155 from livenet through oracle
    /// @param _user address
    /// @param _tokenContractAddress address : ERC1155 smart contract
    /// @param _tokenId uint256 : tokenId of ERC1155
    /// @param _amount uint256
    /// @param _transactionHashDeposit bytes32 : hash of transaction from livenet, for anti replay
    /// @return bool
    function receiveDepotERC1155_V1(
        address _user,
        address _tokenContractAddress,
        uint256 _tokenId,
        uint256 _amount,
        bytes32 _transactionHashDeposit
    )
    public
    delegatedSendIsOracle_V1
    isUniqueTransactionHashDeposit_V1(_transactionHashDeposit)
    returns (bool)
    {
        _addDepot_V1(_user, _tokenContractAddress, _tokenId, _amount);

        emit LogAddDepot_V1(
            _user,
            _tokenContractAddress,
            _tokenId,
            _amount,
            getBalanceERC1155_V1(_user, _tokenContractAddress, _tokenId),
            _transactionHashDeposit
        );

        return true;
    }

    /// @notice receive reward DepotErc1155
    /// @dev Receive reward deposit of ERC1155 from livenet through oracle
    /// @param _user address
    /// @param _tokenContractAddress address : ERC1155 smart contract
    /// @param _tokenId uint256 : tokenId of ERC1155
    /// @param _amount uint256
    /// @param _transactionHashDeposit bytes32 : hash of transaction from livenet, history only
    /// @return bool
    function receiveRewardDepotERC1155_V1(
        address _user,
        address _tokenContractAddress,
        uint256 _tokenId,
        uint256 _amount,
        bytes32 _transactionHashDeposit
    ) public delegatedSendIsOracle_V1 returns (bool) {
        _addDepot_V1(_user, _tokenContractAddress, _tokenId, _amount);

        emit LogAddRewardDepot_V1(
            _user,
            _tokenContractAddress,
            _tokenId,
            _amount,
            getBalanceERC1155_V1(_user, _tokenContractAddress, _tokenId),
            _transactionHashDeposit
        );

        return true;
    }

    /// @notice internal transaction for add depot ETH
    function _addDepotEth_V1(address _user, uint256 _amount)
        internal
        returns (bool)
    {
        return _addDepot_V1(_user, address(0), uint256(0), _amount);
    }

    /// @notice internal transaction for add depot ERC20
    function _addDepotERC20_V1(
        address _user,
        address _tokenContractAddress,
        uint256 _amount
    ) internal returns (bool) {
        return _addDepot_V1(_user, _tokenContractAddress, uint256(0), _amount);
    }

    /// @notice internal transaction for add depot ERC721
    function _addDepotERC721_V1(
        address _user,
        address _tokenContractAddress,
        uint256 _tokenId
    ) internal returns (bool) {
        require(
            getBalanceERC721_V1(_user, _tokenContractAddress, _tokenId) == 0,
            "ERC721 is already own"
        );

        return _addDepot_V1(_user, _tokenContractAddress, _tokenId, 1);
    }

    /// @notice internal transaction for add depot ERC1155
    function _addDepot_V1(
        address _user,
        address _tokenContractAddress,
        uint256 _tokenId,
        uint256 _amount
    ) internal returns (bool) {
        require(_amount > 0, "Amount must be greater than 0");

        tokens[_tokenContractAddress][_tokenId][_user].amount = tokens[_tokenContractAddress][_tokenId][_user].amount.add(
            _amount
        );

        return true;
    }

    /// @notice internal transaction for sub depot ETH
    function _subDepotEth_V1(address _user, uint256 _amount)
        internal
        returns (bool)
    {
        return _subDepot_V1(_user, address(0), uint256(0), _amount);
    }

    /// @notice internal transaction for sub depot ERC20
    function _subDepotERC20(
        address _user,
        address _tokenContractAddress,
        uint256 _amount
    ) internal returns (bool) {
        return _subDepot_V1(_user, _tokenContractAddress, uint256(0), _amount);
    }

    /// @notice internal transaction for sub depot ERC721
    function _subDepotERC721(
        address _user,
        address _tokenContractAddress,
        uint256 _tokenId
    ) internal returns (bool) {
        return _subDepot_V1(_user, _tokenContractAddress, _tokenId, 1);
    }

    /// @notice internal transaction for sub depot ERC1155
    function _subDepot_V1(
        address _user,
        address _tokenContractAddress,
        uint256 _tokenId,
        uint256 _amount
    ) internal returns (bool) {
        require(
            tokens[_tokenContractAddress][_tokenId][_user].amount >= _amount,
            "Amount too low"
        );

        tokens[_tokenContractAddress][_tokenId][_user].amount = tokens[_tokenContractAddress][_tokenId][_user].amount.sub(
            _amount
        );

        return true;
    }

    /// @notice get balance Eth for a user
    /// @param _user address
    /// @return _balanceOf uint256 balance of user
    function getBalanceEth_V1(address _user) public view returns (uint256 _balanceOf) {
        return _getBalance_V1(_user, address(0), uint256(0));
    }

    /// @notice get balance ERC20 for a user
    /// @param _user address
    /// @param _tokenContractAddress address : ERC20 smart contract
    /// @return _balanceOf uint256 balance of user
    function getBalanceERC20_V1(address _user, address _tokenContractAddress)
        public
        view
        returns (uint256 _balanceOf)
    {
        return _getBalance_V1(_user, _tokenContractAddress, uint256(0));
    }

    /// @notice get balance ERC721 for a user
    /// @param _user address
    /// @param _tokenContractAddress address : ERC721 smart contract
    /// @param _tokenId uint256 : tokenId of ERC721
    /// @return _balanceOf uint256 balance of user (unique ERC721 amount)
    function getBalanceERC721_V1(
        address _user,
        address _tokenContractAddress,
        uint256 _tokenId
    ) public view returns (uint256 _balanceOf) {
        return _getBalance_V1(_user, _tokenContractAddress, _tokenId);
    }

    /// @notice internal get balance ERC1155 for a user
    /// @param _user address
    /// @param _tokenContractAddress address : ERC1155 smart contract
    /// @param _tokenId uint256 : tokenId of ERC1155
    /// @return _balanceOf uint256 balance of user
    function getBalanceERC1155_V1(
        address _user,
        address _tokenContractAddress,
        uint256 _tokenId
    ) public view returns (uint256 _balanceOf) {
        return _getBalance_V1(_user, _tokenContractAddress, _tokenId);
    }

    /// @notice internal get balance ERC1155 for a user
    /// @param _user address
    /// @param _tokenContractAddress address : ERC1155 smart contract
    /// @param _tokenId uint256 : tokenId of ERC1155
    /// @return _balanceOf uint256 balance of user
    function _getBalance_V1(
        address _user,
        address _tokenContractAddress,
        uint256 _tokenId
    ) internal view returns (uint256 _balanceOf) {
        return tokens[_tokenContractAddress][_tokenId][_user].amount;
    }

    /// @notice internal lock of depot Eth
    /// @param _user address
    /// @param _amount uint256 : amount to lock
    /// @param _lockedFor uin256 : id to lock for
    /// @return _success bool
    function _addDepotLockedEth_V1(
        address _user,
        uint256 _amount,
        uint256 _lockedFor
    ) internal returns (bool _success) {
        return _addDepotLocked_V1(
            _user,
            address(0),
            uint256(0),
            _amount,
            _lockedFor
        );
    }

    /// @notice internal lock of depot ERC20
    /// @param _user address
    /// @param _tokenContractAddress address : ERC20 smart contract
    /// @param _amount uint256 : amount to lock
    /// @param _lockedFor uin256 : id to lock for
    /// @return _success bool
    function _addDepotLockedERC20_V1(
        address _user,
        address _tokenContractAddress,
        uint256 _amount,
        uint256 _lockedFor
    ) internal returns (bool _success) {
        return _addDepotLocked_V1(
            _user,
            _tokenContractAddress,
            uint256(0),
            _amount,
            _lockedFor
        );
    }

    /// @notice internal lock of depot ERC721
    /// @param _user address
    /// @param _tokenContractAddress address : ERC721 smart contract
    /// @param _tokenId uint256 : tokenId of ERC721
    /// @param _lockedFor uin256 : id to lock for
    /// @return _success bool
    function _addDepotLockedERC721_V1(
        address _user,
        address _tokenContractAddress,
        uint256 _tokenId,
        uint256 _lockedFor
    ) internal returns (bool _success) {
        return _addDepotLocked_V1(
            _user,
            _tokenContractAddress,
            _tokenId,
            1,
            _lockedFor
        );
    }

    /// @notice internal lock of depot ERC1155
    /// @param _user address
    /// @param _tokenContractAddress address : ERC1155 smart contract
    /// @param _tokenId uint256 : tokenId of ERC1155
    /// @param _amount uint256 : amount to lock
    /// @param _lockedFor uin256 : id to lock for
    /// @return _success bool
    function _addDepotLocked_V1(
        address _user,
        address _tokenContractAddress,
        uint256 _tokenId,
        uint256 _amount,
        uint256 _lockedFor
    ) internal returns (bool _success) {
        require(_amount > 0, "Amount must be greater than 0");

        // if is the first lock , push into list
        if (!tokens[_tokenContractAddress][_tokenId][_user].lockedData[_lockedFor].isValue) {
            tokens[_tokenContractAddress][_tokenId][_user].lockedList.push(
                _lockedFor
            );

            tokens[_tokenContractAddress][_tokenId][_user].lockedData[_lockedFor].amount = _amount;
            tokens[_tokenContractAddress][_tokenId][_user].lockedData[_lockedFor].isValue = true;

            return true;
        }

        tokens[_tokenContractAddress][_tokenId][_user].lockedData[_lockedFor].amount = tokens[_tokenContractAddress][_tokenId][_user].lockedData[_lockedFor].amount.add(
            _amount
        );

        return true;
    }

    /// @notice internal unlock of depot Eth
    /// @param _user address
    /// @param _amount uint256 : amount to lock
    /// @param _lockedFor uin256 : id to lock for
    /// @return _success bool
    function _subDepotLockedEth_V1(
        address _user,
        uint256 _amount,
        uint256 _lockedFor
    ) internal returns (bool _success) {
        return _subDepotLocked_V1(
            _user,
            address(0),
            uint256(0),
            _amount,
            _lockedFor
        );
    }

    /// @notice internal unlock of depot ERC20
    /// @param _user address
    /// @param _tokenContractAddress address : ERC20 smart contract
    /// @param _amount uint256 : amount to lock
    /// @param _lockedFor uin256 : id to lock for
    /// @return _success bool
    function _subDepotLockedERC20_V1(
        address _user,
        address _tokenContractAddress,
        uint256 _amount,
        uint256 _lockedFor
    ) internal returns (bool _success) {
        return _subDepotLocked_V1(
            _user,
            _tokenContractAddress,
            uint256(0),
            _amount,
            _lockedFor
        );
    }

    /// @notice internal unlock of depot ERC721
    /// @param _user address
    /// @param _tokenContractAddress address : ERC721 smart contract
    /// @param _tokenId uint256 : tokenId of ERC721
    /// @param _lockedFor uin256 : id to lock for
    /// @return _success bool
    function _subDepotLockedERC721_V1(
        address _user,
        address _tokenContractAddress,
        uint256 _tokenId,
        uint256 _lockedFor
    ) internal returns (bool _success) {
        return _subDepotLocked_V1(
            _user,
            _tokenContractAddress,
            _tokenId,
            1,
            _lockedFor
        );
    }

    /// @notice internal unlock of depot ERC1155
    /// @param _user address
    /// @param _tokenContractAddress address : ERC1155 smart contract
    /// @param _tokenId uint256 : tokenId of ERC1155
    /// @param _amount uint256 : amount to lock
    /// @param _lockedFor uin256 : id to lock for
    /// @return _success bool
    function _subDepotLocked_V1(
        address _user,
        address _tokenContractAddress,
        uint256 _tokenId,
        uint256 _amount,
        uint256 _lockedFor
    ) internal returns (bool _success) {
        require(
            tokens[_tokenContractAddress][_tokenId][_user].lockedData[_lockedFor].amount >= _amount,
            "Locked amount too low"
        );

        tokens[_tokenContractAddress][_tokenId][_user].lockedData[_lockedFor].amount = tokens[_tokenContractAddress][_tokenId][_user].lockedData[_lockedFor].amount.sub(
            _amount
        );

        return true;
    }

    /// @notice get locked balance Eth
    /// @param _user address
    /// @param _lockedFor uin256 : id to lock for
    /// @return _balanceOf uint256
    function getBalanceLockedEth_V1(address _user, uint256 _lockedFor)
        public
        view
        returns (uint256 _balanceOf)
    {
        return _getBalanceLocked_V1(_user, address(0), uint256(0), _lockedFor);
    }

    /// @notice get locked balance ERC20
    /// @param _user address
    /// @param _tokenContractAddress address : ERC20 smart contract
    /// @param _lockedFor uin256 : id to lock for
    /// @return _balanceOf uint256
    function getBalanceLockedERC20_V1(
        address _user,
        address _tokenContractAddress,
        uint256 _lockedFor
    ) public view returns (uint256 _balanceOf) {
        return _getBalanceLocked_V1(
            _user,
            _tokenContractAddress,
            uint256(0),
            _lockedFor
        );
    }

    /// @notice get locked balance ERC721
    /// @param _user address
    /// @param _tokenContractAddress address : ERC721 smart contract
    /// @param _tokenId uint256 : tokenId of ERC721
    /// @param _lockedFor uin256 : id to lock for
    /// @return _balanceOf uint256
    function getBalanceLockedERC721_V1(
        address _user,
        address _tokenContractAddress,
        uint256 _tokenId,
        uint256 _lockedFor
    ) public view returns (uint256 _balanceOf) {
        return _getBalanceLocked_V1(
            _user,
            _tokenContractAddress,
            _tokenId,
            _lockedFor
        );
    }

    /// @notice get locked balance ERC1155
    /// @param _user address
    /// @param _tokenContractAddress address : ERC1155 smart contract
    /// @param _tokenId uint256 : tokenId of ERC1155
    /// @param _lockedFor uin256 : id to lock for
    /// @return _balanceOf uint256
    function getBalanceLockedERC1155_V1(
        address _user,
        address _tokenContractAddress,
        uint256 _tokenId,
        uint256 _lockedFor
    ) public view returns (uint256 _balanceOf) {
        return _getBalanceLocked_V1(
            _user,
            _tokenContractAddress,
            _tokenId,
            _lockedFor
        );
    }

    /// @notice internal get locked balance ERC1155
    /// @param _user address
    /// @param _tokenContractAddress address : ERC1155 smart contract
    /// @param _tokenId uint256 : tokenId of ERC1155
    /// @param _lockedFor uin256 : id to lock for
    /// @return _balanceOf uint256
    function _getBalanceLocked_V1(
        address _user,
        address _tokenContractAddress,
        uint256 _tokenId,
        uint256 _lockedFor
    ) internal view returns (uint256 _balanceOf) {
        return tokens[_tokenContractAddress][_tokenId][_user].lockedData[_lockedFor].amount;
    }

    /// @notice For previous compatiblity : Lock part of deposit to a called smart contract
    /// @param _amount uint256 amount to lock
    /// @param _refundUser address : refund previews locked fo same lockId : uint256(msg.sender)
    /// @dev tx.origin : origin user call parent smart contract
    /// @dev msg.sender : smart contract of parent smart contract
    /// @return _success
    function lockDeposit(uint256 _amount, address _refundUser)
        public
        returns (bool _success)
    {

        if(_getBalance_V1(tx.origin, address(0), uint(0)) <= _amount) {
            return false;
        }


        // For previous compatibility
        if(_refundUser != address(0)){
            emit LogLockDepositRefund(_refundUser, _getBalanceLocked_V1(
                _refundUser,
                address(0),
                uint256(0),
                uint(msg.sender)
            ));
        }
        emit LogNewDepotLock(tx.origin, _amount);

        return _unlockDeposit_V1(
            _refundUser,
            address(0),
            uint256(0),
            _getBalanceLocked_V1(
                _refundUser,
                address(0),
                uint256(0),
                uint(msg.sender)
            ),
            uint(msg.sender)
        ) && _lockDeposit_V1(
            tx.origin,
            address(0),
            uint256(0),
            _amount,
            uint(msg.sender)
        );
    }

    /// @notice lock of depot Eth
    /// @param _amount uint256 : amount to lock
    /// @param _lockedFor uin256 : id to lock for
    /// @return _success bool
    function lockDepositEth_V1(
        uint256 _amount,
        uint256 _lockedFor
    ) public returns (bool _success) {
        return _lockDeposit_V1(
            tx.origin,
            address(0),
            uint256(0),
            _amount,
            _lockedFor
        );
    }

    /// @notice lock of depot ERC20
    /// @param _tokenContractAddress address : ERC20 smart contract
    /// @param _amount uint256 : amount to lock
    /// @param _lockedFor uin256 : id to lock for
    /// @return _success bool
    function lockDepositERC20_V1(
        address _tokenContractAddress,
        uint256 _amount,
        uint256 _lockedFor
    ) public returns (bool _success) {
        return _lockDeposit_V1(
            tx.origin,
            _tokenContractAddress,
            uint256(0),
            _amount,
            _lockedFor
        );
    }

    /// @notice internal lock of depot ERC721
    /// @param _tokenContractAddress address : ERC721 smart contract
    /// @param _tokenId uint256 : tokenId of ERC721
    /// @param _lockedFor uin256 : id to lock for
    /// @return _success bool
    function lockDepositERC721_V1(
        address _tokenContractAddress,
        uint256 _tokenId,
        uint256 _lockedFor
    ) public returns (bool _success) {
        return _lockDeposit_V1(
            tx.origin,
            _tokenContractAddress,
            _tokenId,
            1,
            _lockedFor
        );
    }

    /// @notice internal lock of depot ERC1155
    /// @param _tokenContractAddress address : ERC1155 smart contract
    /// @param _tokenId uint256 : tokenId of ERC1155
    /// @param _amount uint256 : amount to lock
    /// @param _lockedFor uin256 : id to lock for
    /// @return _success bool
    function lockDepositERC1155_V1(
        address _tokenContractAddress,
        uint256 _tokenId,
        uint256 _amount,
        uint256 _lockedFor
    ) public returns (bool _success) {
        return _lockDeposit_V1(
            tx.origin,
            _tokenContractAddress,
            _tokenId,
            _amount,
            _lockedFor
        );
    }


    /// @notice internal Lock part of deposit to a called smart contract
    /// @param _user address
    /// @param _tokenContractAddress address : ERC1155 smart contract
    /// @param _tokenId uint256 : tokenId of ERC1155
    /// @param _amount uint256 amount to lock
    /// @param _lockedFor uint256 lockedId
    /// @return _success
    // TODO vérifer que l'on ne peu pas l'appeler/modifier les données depuis le proxy
    function _lockDeposit_V1(
        address _user,
        address _tokenContractAddress,
        uint256 _tokenId,
        uint256 _amount,
        uint256 _lockedFor
    ) internal returns (bool _success) {
        require(
            _getBalance_V1(_user, _tokenContractAddress, _tokenId) >= _amount,
            "Not enouth amount to locked"
        );

        _addDepotLocked_V1(
            _user,
            _tokenContractAddress,
            _tokenId,
            _amount,
            _lockedFor
        );
        _subDepot_V1(_user, _tokenContractAddress, _tokenId, _amount);

        emit LogNewDepotLock_V1(
            _user,
            _tokenContractAddress,
            _tokenId,
            _amount,
            _lockedFor
        );

        return true;
    }

    /// @notice internal Unlock part of deposit to a called smart contract
    /// @param _user address
    /// @param _tokenContractAddress address : ERC1155 smart contract
    /// @param _tokenId uint256 : tokenId of ERC1155
    /// @param _amount uint256 amount to lock
    /// @param _lockedFor uint256 lockedId
    /// @return _success
    function _unlockDeposit_V1(
        address _user,
        address _tokenContractAddress,
        uint256 _tokenId,
        uint256 _amount,
        uint256 _lockedFor
    ) internal returns (bool _success) {
        if (_amount == 0) {
            return true;
        }

        require(
            _getBalanceLocked_V1(
                _user,
                _tokenContractAddress,
                _tokenId,
                _lockedFor
            ) >= _amount,
            "Not enouth amount locked"
        );

        _subDepotLocked_V1(
            _user,
            _tokenContractAddress,
            _tokenId,
            _amount,
            _lockedFor
        );
        _addDepot_V1(_user, _tokenContractAddress, _tokenId, _amount);

        emit LogRefundDepotLock_V1(
            _user,
            _tokenContractAddress,
            _tokenId,
            _amount,
            _lockedFor
        );

        return true;

    }
    /// @notice for previous compatibility : endorse locked deposit to a called smart contract
    /// @param _amount uint256 amount to endorse
    /// @param _user address
    /// @dev msg.sender : smart contract of parent smart contract
    /// @return _success
    function endorse(uint256 _amount, address _user) public returns (bool _success) {

        if( _getBalanceLocked_V1(
            _user,
            address(0),
            uint256(0),
            uint(msg.sender)
        ) != _amount) {
            return false;
        }

        // For previous compatibility
        emit LogEndorse(msg.sender, _user, _amount);

        return _endorse_V1(
            _user,
            address(0),
            uint(0),
            _amount,
            uint(msg.sender)
        );
    }

    /// @notice internal Unlock part of deposit to a called smart contract
    /// @param _user address
    /// @param _tokenContractAddress address : ERC1155 smart contract
    /// @param _tokenId uint256 : tokenId of ERC1155
    /// @param _amount uint256 amount to lock
    /// @param _lockedFor uint256 lockedId
    /// @return _success
    function _endorse_V1(
        address _user,
        address _tokenContractAddress,
        uint256 _tokenId,
        uint256 _amount,
        uint256 _lockedFor
    ) internal returns (bool _success) {
        require(
            _getBalanceLocked_V1(
                _user,
                _tokenContractAddress,
                _tokenId,
                _lockedFor
            ) >= _amount,
            "Not enouth amount locked"
        );

        _subDepotLocked_V1(
            _user,
            _tokenContractAddress,
            _tokenId,
            _amount,
            _lockedFor
        );

        emit LogEndorse_V1(
            _user,
            _tokenContractAddress,
            _tokenId,
            _amount,
            _lockedFor
        );

        return true;
    }


    /// @notice get number of depot eth lock for a user
    /// @param _user address
    /// @return _depotEthLockCount uint16
    function getDepotEthLockedCountForUser_V1(address _user)
        public
        view
        returns (uint16 _depotEthLockCount)
    {
        return _getDepotLockedCountForUser_V1(_user, address(0), uint(0));
    }

    /// @notice internal get number of depot eth lock for a user
    /// @param _user address
    /// @param _tokenContractAddress address : ERC1155 smart contract
    /// @param _tokenId uint256 : tokenId of ERC1155
    /// @return _depotEthLockCount uint16
    function _getDepotLockedCountForUser_V1(
        address _user,
        address _tokenContractAddress,
        uint256 _tokenId
    ) internal view returns (uint16 _depotEthLockCount) {
        return uint16(
            tokens[_tokenContractAddress][_tokenId][_user].lockedList.length
        );
    }

    /// @notice get lockedFor and amount of depot eth lock for a user and index
    /// @param _user address
    /// @param _index uint256
    /// @return _lockedFor uint256, _amountLocked uint256
    function getDepotEthLockedDataForUserByIndex_V1(
        address _user,
        uint256 _index
    ) public view returns (uint256 _lockedFor, uint256 _amountLocked) {
        return _getDepotLockedDataForUserByIndex_V1(
            _user,
            address(0),
            uint(0),
            _index
        );
    }

    /// @notice internal get lockedFor and amount of depot lock for a user and index
    /// @param _user address
    /// @param _tokenContractAddress address : ERC1155 smart contract
    /// @param _tokenId uint256 : tokenId of ERC1155
    /// @param _index uint256
    /// @return _lockedFor uint256, _amountLocked uint256
    function _getDepotLockedDataForUserByIndex_V1(
        address _user,
        address _tokenContractAddress,
        uint256 _tokenId,
        uint256 _index
    ) internal view returns (uint256 _lockedFor, uint256 _amountLocked) {
        _lockedFor = tokens[_tokenContractAddress][_tokenId][_user].lockedList[_index];
        _amountLocked = _getBalanceLocked_V1(
            _user,
            _tokenContractAddress,
            _tokenId,
            _lockedFor
        );
    }

    /// @notice get total locked amount for a user
    /// @param _user address
    /// @return _totalAmountLocked uint256
    function getDepotEthLockedAmountForUser_V1(address _user)
        public
        view
        returns (uint256 _totalAmountLocked)
    {
        return _getDepotLockedAmountForUser_V1(_user, address(0), uint(0));
    }

    /// @notice internal get total locked amount for a user
    /// @param _user address
    /// @param _tokenContractAddress address : ERC1155 smart contract
    /// @param _tokenId uint256 : tokenId of ERC1155
    /// @return _totalAmountLocked uint256
    function _getDepotLockedAmountForUser_V1(
        address _user,
        address _tokenContractAddress,
        uint256 _tokenId
    ) internal view returns (uint256 _totalAmountLocked) {
        uint16 _lockedListLength = uint16(
            tokens[_tokenContractAddress][_tokenId][_user].lockedList.length
        );

        if (_lockedListLength == 0) {
            return 0;
        }

        for (uint16 index = 0; index < _lockedListLength; index++) {
            uint _amountLocked;

            (, _amountLocked) = _getDepotLockedDataForUserByIndex_V1(
                _user,
                _tokenContractAddress,
                _tokenId,
                index
            );

            _totalAmountLocked = _totalAmountLocked.add(_amountLocked);
        }
    }


    /// @notice withdrawal depot eth
    /// @param _amount uint256
    function withdrawalEth_V1(uint256 _amount) public {

        _withdrawal_V1(msg.sender, address(0), uint(0), _amount);

        // For previous compatibility
        emit LogWithdrawal(msg.sender, _amount);

        emit LogWithdrawal_V1(msg.sender, address(0), uint(0),  _amount);
    }


    /// @notice withdrawal ERC20
    /// @param _tokenContractAddress address : ERC20 smart contract
    /// @param _amount uint256
    function withdrawalERC20_V1(address _tokenContractAddress, uint256 _amount)
    public
    {
        _withdrawal_V1(msg.sender, _tokenContractAddress, uint256(0), _amount);

        emit LogWithdrawal_V1(msg.sender, _tokenContractAddress, uint(0),  _amount);
    }

    /// @notice withdrawal ERC721
    /// @param _user address
    /// @param _tokenContractAddress address : ERC721 smart contract
    /// @param _tokenId uint256 : tokenId of ERC721
    function withdrawalERC721_V1(
        address _user,
        address _tokenContractAddress,
        uint256 _tokenId
    ) public {
        _withdrawal_V1(msg.sender, _tokenContractAddress, _tokenId, uint256(1));

        emit LogWithdrawal_V1(msg.sender, _tokenContractAddress, _tokenId,  uint256(1));
    }

    /// @notice withdrawal ERC1155
    /// @param _user address
    /// @param _tokenContractAddress address : ERC1155 smart contract
    /// @param _tokenId uint256 : tokenId of ERC1155
    /// @param _amount uint256
    function withdrawalERC1155_V1(
        address _user,
        address _tokenContractAddress,
        uint256 _tokenId,
        uint256 _amount
    ) public {
        _withdrawal_V1(msg.sender, _tokenContractAddress, _tokenId, _amount);

        emit LogWithdrawal_V1(msg.sender, _tokenContractAddress, _tokenId,  _amount);
    }

    /// @notice internal withdrawal
    /// @param _user address
    /// @param _tokenContractAddress address : ERC1155 smart contract
    /// @param _tokenId uint256 : tokenId of ERC1155
    /// @param _amount uint256
    function _withdrawal_V1(
        address _user,
        address _tokenContractAddress,
        uint256 _tokenId,
        uint256 _amount
    ) public{

        require(_amount > 0, "Amount must be greater than 0");
        require(_getBalance_V1(_user, _tokenContractAddress, _tokenId) >= _amount, "Amount too low");

        _subDepot_V1(_user, _tokenContractAddress, _tokenId, _amount);
    }

    /// @notice set withdrawalVoucher through oracle
    /// @param _depositContractAddress address
    /// @param _oracleRSV bytes
    /// @param _signedRawTxWithdrawal bytes
    function setWithdrawalVoucher_V1(
        address _depositContractAddress,
        bytes memory _oracleRSV,
        bytes memory _signedRawTxWithdrawal
    ) public delegatedSendIsOracle_V1 {
        address _withdrawalSigner;
        uint256 _withdrawalAmount;
        bytes32 _withdrawalVoucherHash = keccak256(_signedRawTxWithdrawal);

        (_withdrawalSigner, _withdrawalAmount) = AuctionityLibraryDecodeRawTx_V1.decodeRawTxGetWithdrawalInfo_V1(
            _signedRawTxWithdrawal,
            getAuctionityChainId_V1()
        );

        require(
            _withdrawalVoucherOracleSignatureVerification_V1(
                _depositContractAddress,
                _withdrawalSigner,
                _withdrawalAmount,
                _withdrawalVoucherHash,
                _oracleRSV
            ),
            "Withdrawal voucher invalid signature of oracle"
        );

        uint16 _withdrawalVoucherIndex = uint16(
            withdrawals[_withdrawalSigner].withdrawalVoucherList.push("0x0") - 1
        );
        uint _withdrawalVoucherOffset;

        _setWithdrawalVoucherSize_V1(
            _withdrawalSigner,
            _withdrawalVoucherIndex,
            _signedRawTxWithdrawal.length
        );
        setWithdrawalVoucherSelector_V1(
            _withdrawalSigner,
            _withdrawalVoucherIndex
        );

        _withdrawalVoucherOffset = _setWithdrawalVoucherParam1_V1(
            _withdrawalSigner,
            _withdrawalVoucherIndex,
            _oracleRSV
        );
        _withdrawalVoucherOffset = _setWithdrawalVoucherParam2_V1(
            _withdrawalVoucherOffset,
            _withdrawalSigner,
            _withdrawalVoucherIndex,
            _signedRawTxWithdrawal
        );

        bytes memory _withdrawalVoucher = withdrawals[_withdrawalSigner].withdrawalVoucherList[_withdrawalVoucherIndex];

        require(
            withdrawals[_withdrawalSigner].withdrawalVoucher[keccak256(
                _withdrawalVoucher
            )] == 0,
            "Withdrawal voucher already exist"
        );

        withdrawals[_withdrawalSigner].withdrawalVoucher[keccak256(
            _withdrawalVoucher
        )] = _withdrawalVoucherIndex;

        // For previous compatibility
        emit LogSetWithdrawalVoucher(
            _withdrawalSigner,
            _withdrawalAmount,
            _withdrawalVoucher
        );

        emit LogSetWithdrawalVoucher_V1(
            _withdrawalSigner,
            _withdrawalAmount,
            _withdrawalVoucher
        );
    }
    
    /// @notice initiate withdrawalVoucher bytes
    /// @param _user address
    /// @param _withdrawalVoucherIndex uint16 index of voucher
    /// @param _signedRawTxWithdrawalLength bytes
    function _setWithdrawalVoucherSize_V1(
        address _user,
        uint16 _withdrawalVoucherIndex,
        uint _signedRawTxWithdrawalLength
    ) internal {
        uint _withdrawalVoucherLength = 4 + 2 * 32 + (((65 / 32) + 1) * 32) + 32 + (((_signedRawTxWithdrawalLength / 32) + 1) * 32); // start of rlp // 2 param // data : rsvOracle // length + signedRawTxCreateAuction

        withdrawals[_user].withdrawalVoucherList[_withdrawalVoucherIndex] = new bytes(
            _withdrawalVoucherLength
        );
    }

    /// @notice set selector of withdrawalVoucher
    /// @param _user address
    /// @param _withdrawalVoucherIndex uint16 index of voucher
    function setWithdrawalVoucherSelector_V1(
        address _user,
        uint16 _withdrawalVoucherIndex
    ) internal {
        // 0x6fc60a5e : bytes4(keccak256('withdrawalVoucher_V1(bytes,bytes)'))

        bytes4 topic = 0x6fc60a5e;
        for (uint8 i = 0; i < 4; i++) {
            withdrawals[_user].withdrawalVoucherList[_withdrawalVoucherIndex][i] = bytes1(
                topic[i]
            );
        }
    }
    /// @notice set 1st param of withdrawalVoucher : _oracleRSV
    /// @param _user address
    /// @param _withdrawalVoucherIndex uint16 index of voucher
    /// @param _oracleRSV bytes
    /// @return position of next free data in WV
    function _setWithdrawalVoucherParam1_V1(
        address _user,
        uint16 _withdrawalVoucherIndex,
        bytes memory _oracleRSV
    ) internal returns (uint) {
        uint i;
        bytes32 _bytes32Position = bytes32(uint(2 * 32));

        for (i = 0; i < 32; i++) {
            withdrawals[_user].withdrawalVoucherList[_withdrawalVoucherIndex][4 + i] = bytes1(
                _bytes32Position[i]
            );
        }

        bytes32 _bytes32Length = bytes32(uint(65));

        for (i = 0; i < 32; i++) {
            withdrawals[_user].withdrawalVoucherList[_withdrawalVoucherIndex][4 + uint(
                _bytes32Position
            ) + i] = bytes1(_bytes32Length[i]);
        }

        for (i = 0; i < 65; i++) {
            withdrawals[_user].withdrawalVoucherList[_withdrawalVoucherIndex][4 + 32 + uint(
                _bytes32Position
            ) + i] = bytes1(_oracleRSV[i]);
        }

        return uint(_bytes32Position) + (((65 / 32) + 1) * 32); // padding 32 bytes
    }

    /// @notice set 2nd param of withdrawalVoucher : _signedRawTxCreateAuction
    /// @param _offset uint256 position of current free data in WV
    /// @param _user address
    /// @param _withdrawalVoucherIndex uint16 index of voucher
    /// @param _signedRawTxWithdrawal bytes
    /// @return position of next free data in WV
    function _setWithdrawalVoucherParam2_V1(
        uint _offset,
        address _user,
        uint16 _withdrawalVoucherIndex,
        bytes memory _signedRawTxWithdrawal
    ) internal returns (uint) {
        uint i;
        bytes32 _bytes32Position = bytes32(_offset);

        for (i = 0; i < 32; i++) {
            withdrawals[_user].withdrawalVoucherList[_withdrawalVoucherIndex][4 + 32 + i] = bytes1(
                _bytes32Position[i]
            );
        }

        bytes32 _bytes32Length = bytes32(_signedRawTxWithdrawal.length);

        for (i = 0; i < 32; i++) {
            withdrawals[_user].withdrawalVoucherList[_withdrawalVoucherIndex][4 + uint(
                _bytes32Position
            ) + i] = bytes1(_bytes32Length[i]);
        }

        for (i = 0; i < _signedRawTxWithdrawal.length; i++) {
            withdrawals[_user].withdrawalVoucherList[_withdrawalVoucherIndex][4 + 32 + uint(
                _bytes32Position
            ) + i] = bytes1(_signedRawTxWithdrawal[i]);
        }

        return uint(
            _bytes32Position
        ) + 32 + (((_signedRawTxWithdrawal.length / 32) + 1) * 32);
    }

    /// @notice verification of oracle RSV
    /// @param _depositContractAddress address
    /// @param _withdrawalSigner address
    /// @param _withdrawalAmount uint256
    /// @param _withdrawalVoucherHash bytes32
    /// @param _oracleRSV bytes
    /// @return _success
    function _withdrawalVoucherOracleSignatureVerification_V1(
        address _depositContractAddress,
        address _withdrawalSigner,
        uint256 _withdrawalAmount,
        bytes32 _withdrawalVoucherHash,
        bytes memory _oracleRSV
    ) internal view returns (bool) {
        bytes32 _hash = keccak256(
            abi.encodePacked(
                _depositContractAddress,
                _withdrawalSigner,
                _withdrawalAmount,
                _withdrawalVoucherHash
            )
        );

        // if oracle is the signer of this withdrawal
        address _oracleEcrecoverSigner = AuctionityLibraryDecodeRawTx_V1.ecrecoverSigner_V1(
            keccak256(
                abi.encodePacked("\x19Ethereum Signed Message:\n32", _hash)
            ),
            _oracleRSV,
            0
        );

        return _oracleEcrecoverSigner == oracle;
    }

    /// @notice Get number of withdrawal voucher list for a user
    /// @param _user address
    /// @return _numberOfWithdrawalVoucher
    function getUserWithdrawalVoucherLength_V1(address _user)
        public
        view
        returns (uint16 _numberOfWithdrawalVoucher)
    {
        return uint16(withdrawals[_user].withdrawalVoucherList.length);
    }

    /// @notice Get Withdrawal voucher for a user at index
    /// @param _user address
    /// @param _index uint16
    /// @return voucher bytes
    function getWithdrawalVoucherAtIndex_V1(address _user, uint16 _index)
        public
        view
        returns (bytes memory _voucher)
    {
        return withdrawals[_user].withdrawalVoucherList[_index];
    }

    /// @notice Get index fro withdrawalVoucherList from user and voucher hash
    /// @param _user address
    /// @param _voucherHash bytes32
    /// @return _index
    function getWithdrawalVoucherIndex_V1(address _user, bytes32 _voucherHash)
        public
        view
        returns (uint16)
    {
        return withdrawals[_user].withdrawalVoucher[_voucherHash];
    }

    /// @notice Remove withdrawal voucher by replacing the index of withdrawal voucher by the last index in withdrawal voucher list
    /// @dev oracle only
    /// @param _user address
    /// @param _voucherHash bytes32
    function removeWithdrawalVoucher_V1(address _user, bytes32 _voucherHash)
        public
        delegatedSendIsOracle_V1
    {
        uint16 _indexToDelete = withdrawals[_user].withdrawalVoucher[_voucherHash];
        uint16 _length = uint16(
            withdrawals[_user].withdrawalVoucherList.length
        );
        if (_length > 1) {
            bytes memory _hashToMove = withdrawals[_user].withdrawalVoucherList[_length - 1];
            withdrawals[_user].withdrawalVoucherList[_indexToDelete] = _hashToMove;
            withdrawals[_user].withdrawalVoucher[keccak256(
                _hashToMove
            )] = _indexToDelete;
        }

        withdrawals[_user].withdrawalVoucherList.length--;

        // For previous compatibility
        emit LogWithdrawalVoucherHaveBeenRemoved(_user, _voucherHash);

        emit LogWithdrawalVoucherHaveBeenRemoved_V1(_user, _voucherHash);
    }

}
