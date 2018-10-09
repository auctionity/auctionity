pragma solidity ^0.4.24;


import "./SafeMath.sol";
import "./AuctionityLibraryDecodeRawTx.sol";

contract AuctionityTreasurerEth {
    using SafeMath for uint256;

    string public version = 'treasurer-eth-v1';

    address public owner;
    address public oracle;

    uint8 public ethereumChainId;
    uint8 public auctionityChainId;

    // Amount of locked deposit of auction
    struct DepotLockedData {
        uint256 amount;
        bool isValue;
    }

    struct DepotData {
        uint256 amount;                                // amount of deposit available
        mapping (address => DepotLockedData) locked;   // Locked amount of a bid on auction smart contract
        address[] lockedList;                          // List of auction smart contract with a locked amount
        mapping (bytes32 => uint16) withdrawalVoucher; // Mapping of withdrawalVoucherHash => position into withdrawalVoucherList
        bytes[] withdrawalVoucherList;                 // List of withdrawalVoucher
        bool isValue;                                  // is value amount is already set (if not set, push into depotEthList)
    }
    
    address[] public depotEthList;                   // List of deposit users
    mapping (address => DepotData) public depotEth;  // DepotData for users

    // Error Codes
    enum Errors {
        LOCK_DEPOSIT_OVERFLOW,
        WITHDRAWAL_ZERO_AMOUNT,
        WITHDRAWAL_DEPOT_NOT_FOUND,
        WITHDRAWAL_DEPOT_AMOUNT_TOO_LOW,
        WITHDRAWAL_VOUCHER_ALREADY_ADDED
    }

    // Events
    event LogAddDepotEth(address user, uint256 amount, uint256 totalAmount, bytes32 hashTransactionDeposit);
    event LogAddRewardDepotEth(address user, uint256 amount, uint256 totalAmount, bytes32 hashTransactionDeposit);
    event LogWithdrawal(address user, uint256 amount);
    event LogSetWithdrawalVoucher(address user, uint256 amount, bytes voucher);
    event LogWithdrawalVoucherHaveBeenRemoved(address user, bytes32 voucherHash);
    event LogNewDepotLock(address user, uint256 amount);
    event LogLockDepositRefund(address user, uint256 amount);
    event LogEndorse(address auctionAddress, address user, uint256 amount);
    event LogError(string version, string error);

    constructor(uint8 _ethereumChainId, uint8 _auctionityChainId) public {
        ethereumChainId = _ethereumChainId;
        auctionityChainId = _auctionityChainId;
        owner = msg.sender;
    }

    // Modifier
    modifier isOwner() {
        require(msg.sender == owner, "Sender must be owner");
        _;
    }

    modifier isOracle() {
        require(msg.sender == oracle, "Sender must be oracle");
        _;
    }

    function setOracle(address _oracle) public isOwner {
        oracle = _oracle;
    }
    
    /**
     * receiveDepotEth
     * @dev : Receive deposit of eth from livenet through oracle
     */
    function receiveDepotEth(address _user, uint256 _amount, bytes32 _hashTransactionDeposit) public isOracle returns (bool) {
        if (depotEth[_user].isValue == false) {
            depotEth[_user].amount = _amount;
            depotEth[_user].isValue = true;
            depotEthList.push(_user);
        } else {
            depotEth[_user].amount = depotEth[_user].amount.add(_amount);
        }

        emit LogAddDepotEth(_user, _amount, depotEth[_user].amount, _hashTransactionDeposit);

        return true;
    }

    /**
     * receiveRewardDepotEth
     * @dev : Receive reward deposit of eth from livenet through oracle
     */
    function receiveRewardDepotEth(address _user, uint256 _amount, bytes32 _hashTransactionDeposit) public isOracle returns (bool) {
        if (depotEth[_user].isValue == false) {
            depotEth[_user].amount = _amount;
            depotEth[_user].isValue = true;
            depotEthList.push(_user);
        } else {
            depotEth[_user].amount = depotEth[_user].amount.add(_amount);
        }

        emit LogAddRewardDepotEth(_user, _amount, depotEth[_user].amount, _hashTransactionDeposit);

        return true;
    }

    /**
     * lockDeposit
     * @dev Lock un part of deposit to a called smart contract
     *
     * tx.origin : origin user call parent smart contract
     * msg.sender : smart contract of parent smart contract
     */

    function lockDeposit(uint256 _amount, address _refundUser) external
        returns (bool) {

        if(!depotEth[tx.origin].isValue) {
            return false;
        }

        uint256 _amountToLock = _amount;

        // get amount to refund for previews bidder, 0 if doesn't exist
        uint256 _refundAmount = depotEth[_refundUser].locked[msg.sender].amount;

        // if refundUser is equal of currentUser , get difference between old and new amount
        if(_refundUser == tx.origin) {
            _amountToLock = _amount.sub(depotEth[tx.origin].locked[msg.sender].amount);
            _refundAmount = 0;
        }

        // if deposit amount is smaller than amount to lock
        if (depotEth[tx.origin].amount < _amountToLock) {
            return false;
        }

        // if is the first lock , push into list
        if (!depotEth[tx.origin].locked[msg.sender].isValue) {
            depotEth[tx.origin].lockedList.push(msg.sender);
        }

        depotEth[tx.origin].locked[msg.sender].amount = _amount;
        depotEth[tx.origin].locked[msg.sender].isValue = true;
        depotEth[tx.origin].amount = depotEth[tx.origin].amount.sub(_amountToLock);

        emit LogNewDepotLock(tx.origin, _amount);

        if (_refundAmount > 0) {
            // expected overflow of depotEth
            uint256 newUserDepotAmount = depotEth[_refundUser].amount + _refundAmount;
            if (newUserDepotAmount < _refundAmount) {
                emit LogError(version, "LOCK_DEPOSIT_OVERFLOW");
            } else {
                depotEth[_refundUser].locked[msg.sender].amount = 0;
                depotEth[_refundUser].amount = newUserDepotAmount;
                emit LogLockDepositRefund(_refundUser, _refundAmount);
            }
        }

        return true;
    }

    /**
     * endorse
     * @dev : endorse (set to 0) locked deposit to a called smart contract
     *
     * msg.sender : smart contract of parent smart contract
     */
    function endorse(uint256 _amount, address _user) external returns (bool) {
        if(depotEth[_user].locked[msg.sender].amount == _amount){
            depotEth[_user].locked[msg.sender].amount = uint256(0);
            emit LogEndorse(msg.sender, _user, _amount);

            return true;
        }

        return false;
    }

    /*** Withdrawal ***/

    /**
     * withdrawal
     * @dev : The user can ask a withdrawal
     */
    function withdrawal(uint256 _amount) public {
        if(_amount == 0){
            emit LogError(version, "WITHDRAWAL_ZERO_AMOUNT");
            return;
        }

        if(!depotEth[msg.sender].isValue){
            emit LogError(version, "WITHDRAWAL_DEPOT_NOT_FOUND");
            return;
        }

        if (depotEth[msg.sender].amount < _amount) {
            emit LogError(version, "WITHDRAWAL_DEPOT_AMOUNT_TOO_LOW");
            return;
        }

        depotEth[msg.sender].amount = depotEth[msg.sender].amount.sub(_amount);
        emit LogWithdrawal(msg.sender, _amount);
    }

    function setWithdrawalVoucher(address _depositContractAddress, bytes _oracleRSV, bytes _signedRawTxWithdrawal) public isOracle {
        address _withdrawalSigner;
        uint256 _withdrawalAmount;
        bytes32 _withdrawalVoucherHash = keccak256(_signedRawTxWithdrawal);
        
        (_withdrawalSigner, _withdrawalAmount) = AuctionityLibraryDecodeRawTx.decodeRawTxGetWithdrawalInfo(
            _signedRawTxWithdrawal,
            auctionityChainId
        );

        if(!withdrawalVoucherOracleSignatureVerification(_depositContractAddress, _withdrawalSigner, _withdrawalAmount, _withdrawalVoucherHash, _oracleRSV))
        {
            emit LogError(version,'WITHDRAWAL_VOUCHER_ORACLE_INVALID_SIGNATURE');
            return;
        }

        uint16 _withdrawalVoucherIndex = uint16(depotEth[_withdrawalSigner].withdrawalVoucherList.push("0x0") - 1);
        uint _withdrawalVoucherOffset;

        setWithdrawalVoucherSize(_withdrawalSigner, _withdrawalVoucherIndex, _signedRawTxWithdrawal.length);
        setWithdrawalVoucherTopic(_withdrawalSigner, _withdrawalVoucherIndex);

        _withdrawalVoucherOffset = setWithdrawalVoucherParam1(_withdrawalSigner, _withdrawalVoucherIndex, _oracleRSV);
        _withdrawalVoucherOffset = setWithdrawalVoucherParam2(_withdrawalVoucherOffset, _withdrawalSigner, _withdrawalVoucherIndex, _signedRawTxWithdrawal);

        bytes memory _withdrawalVoucher = depotEth[_withdrawalSigner].withdrawalVoucherList[_withdrawalVoucherIndex];
        if(depotEth[_withdrawalSigner].withdrawalVoucher[keccak256(_withdrawalVoucher)] != 0){
            emit LogError(version, "WITHDRAWAL_VOUCHER_ALREADY_ADDED");
            depotEth[_withdrawalSigner].withdrawalVoucherList[_withdrawalVoucherIndex] = "0x";
            depotEth[_withdrawalSigner].withdrawalVoucherList.length--;
            return;
        }

        depotEth[_withdrawalSigner].withdrawalVoucher[keccak256(_withdrawalVoucher)] = _withdrawalVoucherIndex;

        emit LogSetWithdrawalVoucher(_withdrawalSigner, _withdrawalAmount, _withdrawalVoucher);
    }

    function setWithdrawalVoucherSize(address _user, uint16 _withdrawalVoucherIndex, uint _signedRawTxWithdrawalLength) internal {
        uint _withdrawalVoucherLength = 4 + // start of rlp
        2 * 32 + // 2 param
        (((65 / 32) + 1) * 32) + // data : rsvOracle
        32 + (((_signedRawTxWithdrawalLength /32) + 1) * 32); // length + signedRawTxCreateAuction
        
        depotEth[_user].withdrawalVoucherList[_withdrawalVoucherIndex] = new bytes(_withdrawalVoucherLength);
    }

    function setWithdrawalVoucherTopic(address _user, uint16 _withdrawalVoucherIndex) internal{
        // 0x5bf96478 : bytes4(keccak256('withdrawalVoucher(bytes,bytes)'))

        bytes4 topic = 0x5bf96478;
        for(uint8 i = 0; i < 4; i++) {
            depotEth[_user].withdrawalVoucherList[_withdrawalVoucherIndex][i] = bytes1(topic[i]);
        }
    }

    function setWithdrawalVoucherParam1(address _user, uint16 _withdrawalVoucherIndex, bytes _oracleRSV) internal returns (uint){
        uint i;
        bytes32 _bytes32Position = bytes32(2*32);

        for(i = 0; i < 32; i++) {
            depotEth[_user].withdrawalVoucherList[_withdrawalVoucherIndex][4+i] = bytes1(_bytes32Position[i]);
        }

        bytes32 _bytes32Length = bytes32(65);

        for(i = 0; i < 32; i++) {
            depotEth[_user].withdrawalVoucherList[_withdrawalVoucherIndex][4 + uint(_bytes32Position) + i] = bytes1(_bytes32Length[i]);
        }

        for(i = 0; i < 65; i++) {
            depotEth[_user].withdrawalVoucherList[_withdrawalVoucherIndex][4 + 32 + uint(_bytes32Position) + i] = bytes1(_oracleRSV[i]);
        }

        return uint(_bytes32Position) + (((65 / 32) + 1) * 32); // padding 32 bytes
    }

    function setWithdrawalVoucherParam2(uint _offset, address _user, uint16 _withdrawalVoucherIndex, bytes _signedRawTxWithdrawal) internal returns (uint) {
        uint i;
        bytes32 _bytes32Position = bytes32(_offset);

        for(i = 0; i < 32; i++) {
            depotEth[_user].withdrawalVoucherList[_withdrawalVoucherIndex][4 + 32 + i] = bytes1(_bytes32Position[i]);
        }

        bytes32 _bytes32Length = bytes32(_signedRawTxWithdrawal.length);

        for(i = 0; i < 32; i++) {
            depotEth[_user].withdrawalVoucherList[_withdrawalVoucherIndex][4 + uint(_bytes32Position) + i] = bytes1(_bytes32Length[i]);
        }

        for(i = 0; i < _signedRawTxWithdrawal.length; i++) {
            depotEth[_user].withdrawalVoucherList[_withdrawalVoucherIndex][4 + 32 + uint(_bytes32Position) + i] = bytes1(_signedRawTxWithdrawal[i]);
        }

        return uint(_bytes32Position) + 32 + (((_signedRawTxWithdrawal.length / 32) + 1) * 32);
    }

    function withdrawalVoucherOracleSignatureVerification(
        address _depositContractAddress,
        address _withdrawalSigner,
        uint256 _withdrawalAmount,
        bytes32 _withdrawalVoucherHash,
        bytes _oracleRSV
    ) internal view returns (bool) {
        bytes32 _hash = keccak256(abi.encodePacked(_depositContractAddress, _withdrawalSigner, _withdrawalAmount, _withdrawalVoucherHash));

        // if oracle is the signer of this withdrawal
        address _oracleEcrecoverSigner = AuctionityLibraryDecodeRawTx.ecrecoverSigner(
            keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", _hash)),
            _oracleRSV,
            0
        );
        
        return _oracleEcrecoverSigner == oracle;
    }
    
    /**
     * Get available deposit for a user
     */
    function getDepotEthUserAmount(address _user) public view returns(uint256 _amount) {
        return depotEth[_user].amount;
    }

    /**
     * Get length of withdrawal voucher list
     */
    function getUserWithdrawalVoucherLength(address _user) public view returns(uint16 _length) {
        return uint16(depotEth[_user].withdrawalVoucherList.length);
    }

    /**
     * Get Withdrawal voucher at index
     */
    function getWithdrawalVoucherAtIndex(address _user, uint16 _index) public view returns (bytes _voucher) {
        return depotEth[_user].withdrawalVoucherList[_index];
    }

    /**
     * Get index of a withdrawal voucher
     */
    function getWithdrawalVoucherIndex(address _user, bytes32 _voucherHash) public view returns (uint16) {
        return depotEth[_user].withdrawalVoucher[_voucherHash];
    }

    /**
     * Remove withdrawal voucher by replacing the index of withdrawal voucher by the last index in withdrawal voucher list
     */
    function removeWithdrawalVoucher(address _user, bytes32 _voucherHash)
    public
    isOracle
    {
        uint16 _indexToDelete = depotEth[_user].withdrawalVoucher[_voucherHash];
        uint16 _length = uint16(depotEth[_user].withdrawalVoucherList.length);
        if(_length > 1) {
            bytes memory _hashToMove = depotEth[_user].withdrawalVoucherList[_length - 1];
            depotEth[_user].withdrawalVoucherList[_indexToDelete] = _hashToMove;
            depotEth[_user].withdrawalVoucher[keccak256(_hashToMove)] = _indexToDelete;
        }

        depotEth[_user].withdrawalVoucherList.length --;

        emit LogWithdrawalVoucherHaveBeenRemoved(_user, _voucherHash);
    }

    /*** View ***/
    function getDepotEthListCount() public view returns(uint16 _depotEthLength) {
        return uint16(depotEthList.length);
    }

    function getDepotEthLockedCountForUser(address _user) public view returns (uint16 _depotEthLockCount) {
        return uint16(depotEth[_user].lockedList.length);
    }

    function getDepotEthLockedAmountForUserByAddress(address _user,address _addressLocked) public view returns (uint256 _amountLocked){
        return depotEth[_user].locked[_addressLocked].amount;
    }

    function getDepotEthLockedDataForUserByIndex(
        address _user,
        uint256 _index
    ) public view returns (address _addressLocked, uint256 _amountLocked) {
        _addressLocked = depotEth[_user].lockedList[_index];
        _amountLocked = getDepotEthLockedAmountForUserByAddress(_user, _addressLocked);
    }

    function getDepotEthLockedAmountForUser(address _user) public view returns (uint256 _totalAmountLocked) {
        uint16 _lockedListLength = uint16(depotEth[_user].lockedList.length);

        if(_lockedListLength == 0) {
            return 0;
        }

        address _addressLocked;

        for (uint16 index = 0; index < _lockedListLength; index++) {
            _addressLocked = depotEth[_user].lockedList[index];
            _totalAmountLocked += depotEth[_user].locked[_addressLocked].amount;
        }
    }
}

