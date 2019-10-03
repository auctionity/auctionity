pragma solidity ^0.5.4;

import "./AuctionityTreasurer_V1.sol";
import "../CommonContract/AuctionityLibrary_V1.sol";
import "../CommonContract/AuctionityChainId_V1.sol";
import "../CommonContract/SafeMath.sol";

contract AuctionityTreasurer_V2 is AuctionityTreasurer_V1 {

    event LogLockDepot_V2(
        address user,
        address tokenContractAddress,
        uint256 tokenId,
        uint256 amount,
        uint256 lockedFor
    );
    event LogUnlockDepot_V2(
        address user,
        address tokenContractAddress,
        uint256 tokenId,
        uint256 amount,
        uint256 lockedFor
    );

    event LogTransferDepot_V2(
        address from,
        address to,
        address tokenContractAddress,
        uint256 tokenId,
        uint256 amount,
        bytes data
    );

    event LogTransferDepotLocked_V2(
        uint256 lockedFor,
        address from,
        address to,
        address tokenContractAddress,
        uint256 tokenId,
        uint256 amount,
        bool keepLock,
        bytes data
    );

    event LogSetWithdrawalVoucher_V2(
        address withdrawalUser,
        bytes voucher
    );


    /// @notice transfer ERC1155
    /// @param _to address of receiver
    /// @param _tokenContractAddress address : ERC1155 smart contract
    /// @param _tokenId uint256 : tokenId of ERC1155
    /// @param _amount uint256
    function transferERC1155_V2(
        address _to,
        address _tokenContractAddress,
        uint256 _tokenId,
        uint256 _amount
    ) public {

        _transferDepot_V2(
            msg.sender,
            _to,
            _tokenContractAddress,
            _tokenId,
            _amount,
            ""
        );

        emit LogTransferDepot_V2(
            msg.sender,
            _to,
            _tokenContractAddress,
            _tokenId,
            _amount,
            ""
        );
    }

    /// @notice withdrawal ERC1155
    /// @param _tokenContractAddress address : ERC1155 smart contract
    /// @param _tokenId uint256 : tokenId of ERC1155
    /// @param _amount uint256
    function withdrawalERC1155_V2(
        address _tokenContractAddress,
        uint256 _tokenId,
        uint256 _amount
    ) public {
        _withdrawal_V1(msg.sender, _tokenContractAddress, _tokenId, _amount);

        emit LogWithdrawal_V1(msg.sender, _tokenContractAddress, _tokenId,  _amount);
    }

    function setWithdrawalVoucher_V2(
        address _withdrawalUser,
        bytes memory _withdrawalVoucher
    ) public delegatedSendIsOracle_V1 {

        require(
            withdrawals[_withdrawalUser].withdrawalVoucher[keccak256(
                _withdrawalVoucher
            )] == 0,
            "Withdrawal voucher already exist"
        );


        uint16 _withdrawalVoucherIndex = uint16(
            withdrawals[_withdrawalUser].withdrawalVoucherList.push("0x0") - 1
        );

        withdrawals[_withdrawalUser].withdrawalVoucherList[_withdrawalVoucherIndex] = _withdrawalVoucher;

        withdrawals[_withdrawalUser].withdrawalVoucher[keccak256(
            _withdrawalVoucher
        )] = _withdrawalVoucherIndex;

        emit LogSetWithdrawalVoucher_V2(
            _withdrawalUser,
            _withdrawalVoucher
        );
    }


    /// @notice internal Lock part of deposit to a called smart contract
    /// @param user address
    /// @param tokenContractAddress address : ERC1155 smart contract
    /// @param tokenId uint256 : tokenId of ERC1155
    /// @param amount uint256 amount to lock
    /// @param lockedFor uint256 lockedId
    function _lockDeposit_V2(
        address user,
        address tokenContractAddress,
        uint256 tokenId,
        uint256 amount,
        uint256 lockedFor
    ) internal {

        if(amount <= 0){

            bytes memory _revertData = abi.encodeWithSelector(
                bytes4(keccak256("ErrorLockDeposit_V2(string,address,address,uint256,uint256,uint256)")),
                "Amount must be greater than zero",
                user,
                tokenContractAddress,
                tokenId,
                amount,
                lockedFor
            );

            assembly {
                let size := mload(_revertData)
                revert(add(_revertData,0x20), size)
            }
        }

        uint256 balanceOfUser = _getBalance_V1(
            user,
            tokenContractAddress,
            tokenId
        );

        if(balanceOfUser < amount){

            bytes memory _revertData = abi.encodeWithSelector(
                bytes4(keccak256("ErrorLockDeposit_V2(string,address,address,uint256,uint256,uint256,uint256)")),
                "Not enough amount to locked",
                user,
                tokenContractAddress,
                tokenId,
                amount,
                balanceOfUser,
                lockedFor
            );

            assembly {
                let size := mload(_revertData)
                revert(add(_revertData,0x20), size)
            }
        }
        _addDepotLocked_V1(
            user,
            tokenContractAddress,
            tokenId,
            amount,
            lockedFor
        );
        _subDepot_V1(user, tokenContractAddress, tokenId, amount);

        emit LogLockDepot_V2(
            user,
            tokenContractAddress,
            tokenId,
            amount,
            lockedFor
        );
    }

    /// @notice internal Unlock part of deposit to a called smart contract
    /// @param user address
    /// @param tokenContractAddress address : ERC1155 smart contract
    /// @param tokenId uint256 : tokenId of ERC1155
    /// @param amount uint256 amount to lock
    /// @param lockedFor uint256 lockedId
    function _unlockDeposit_V2(
        address user,
        address tokenContractAddress,
        uint256 tokenId,
        uint256 amount,
        uint256 lockedFor
    ) internal{
        if(amount <= 0){

            // Generate custom revert data
            bytes memory _revertData = abi.encodeWithSelector(
                bytes4(keccak256("ErrorUnLockDeposit_V2(string,address,address,uint256,uint256,uint256)")),
                "Amount must be greater than zero",
                user,
                tokenContractAddress,
                tokenId,
                amount,
                lockedFor
            );

            assembly {
                let size := mload(_revertData)
                revert(add(_revertData,0x20), size)
            }
        }

        uint256 balanceOfUser = _getBalanceLocked_V1(
            user,
            tokenContractAddress,
            tokenId,
            lockedFor
        );

        if(balanceOfUser < amount){

            // Generate custom revert data
            bytes memory _revertData = abi.encodeWithSelector(
                bytes4(keccak256("ErrorUnLockDeposit_V2(string,address,address,uint256,uint256,uint256,uint256)")),
                "Not enouth amount locked",
                user,
                tokenContractAddress,
                tokenId,
                amount,
                balanceOfUser,
                lockedFor
            );

            assembly {
                let size := mload(_revertData)
                revert(add(_revertData,0x20), size)
            }
        }

        // remove from locked storage and add to available storage
        _subDepotLocked_V1(
            user,
            tokenContractAddress,
            tokenId,
            amount,
            lockedFor
        );
        _addDepot_V1(user, tokenContractAddress, tokenId, amount);

        emit LogUnlockDepot_V2(
            user,
            tokenContractAddress,
            tokenId,
            amount,
            lockedFor
        );
    }

    /// @notice internal transfer depot locked
    /// @param lockedFor uin256 identity of locked requested
    /// @param from address of owner
    /// @param to address of receiver
    /// @param tokenContractAddress address of token contract
    /// @param tokenId uint256 id of token
    /// @param amount uint256 number of token
    /// @param keepLock bool , true if the transfer want to keep tocken locked
    /// @param data bytes additional data for transfer
    function _transferDepotLocked_V2(
        uint256 lockedFor,
        address from,
        address to,
        address tokenContractAddress,
        uint256 tokenId,
        uint256 amount,
        bool keepLock,
        bytes memory data
    ) internal {
        if(amount <= 0){

            // Generate custom revert data
            bytes memory _revertData = abi.encodeWithSelector(
                bytes4(keccak256("ErrorTransferDepotLocked_V2(string,uint256,address,address,address,uint256,uint256,bool,bytes)")),
                "Amount must be greater than zero",
                lockedFor,
                from,
                to,
                tokenContractAddress,
                tokenId,
                amount,
                keepLock,
                data
            );

            assembly {
                let size := mload(_revertData)
                revert(add(_revertData,0x20), size)
            }
        }

        uint256 balanceOfUser = _getBalanceLocked_V1(
            from,
            tokenContractAddress,
            tokenId,
            lockedFor
        );

        if(balanceOfUser < amount) {

            // Generate custom revert data
            bytes memory _revertData = abi.encodeWithSelector(
                bytes4(keccak256("ErrorTransferDepotLocked_V2(string,uint256,address,address,address,uint256,uint256,uint256,bool,bytes)")),
                "Amount too low",
                lockedFor,
                from,
                to,
                tokenContractAddress,
                tokenId,
                amount,
                balanceOfUser,
                keepLock,
                data
            );

            assembly {
                let size := mload(_revertData)
                revert(add(_revertData,0x20), size)
            }
        }

        // remove from locked storage and add to available storage
        _subDepotLocked_V1(
            from,
            tokenContractAddress,
            tokenId,
            amount,
            lockedFor
        );
        _addDepot_V1(to, tokenContractAddress, tokenId, amount);

        if(keepLock)
        {
            _lockDeposit_V2(to, tokenContractAddress, tokenId, amount, lockedFor);
        }
    }

    /// @notice internal transfer depot
    /// @param from address of owner
    /// @param to address of receiver
    /// @param tokenContractAddress address of token contract
    /// @param tokenId uint256 id of token
    /// @param amount uint256 number of token
    /// @param data bytes additional data for transfer
    function _transferDepot_V2(
        address from,
        address to,
        address tokenContractAddress,
        uint256 tokenId,
        uint256 amount,
        bytes memory data
    ) internal {

        if(amount <= 0){

            // Generate custom revert data
            bytes memory _revertData = abi.encodeWithSelector(
                bytes4(keccak256("ErrorTransferDepot_V2(string,address,address,address,uint256,uint256,bytes)")),
                "Amount must be greater than zero",
                from,
                to,
                tokenContractAddress,
                tokenId,
                amount,
                data
            );

            assembly {
                let size := mload(_revertData)
                revert(add(_revertData,0x20), size)
            }
        }

        uint256 balanceOfUser = _getBalance_V1(
            from,
            tokenContractAddress,
            tokenId
        );

        if(
            balanceOfUser < amount
        ) {

            // Generate custom revert data
            bytes memory _revertData = abi.encodeWithSelector(
                bytes4(keccak256("ErrorTransferDepot_V2(string,address,address,address,uint256,uint256,uint256,bytes)")),
                "Amount too low",
                from,
                to,
                tokenContractAddress,
                tokenId,
                amount,
                balanceOfUser,
                data
            );

            assembly {
                let size := mload(_revertData)
                revert(add(_revertData,0x20), size)
            }
        }

        // remove from locked storage and add to available storage
        _subDepot_V1(
            from,
            tokenContractAddress,
            tokenId,
            amount
        );
        _addDepot_V1(to, tokenContractAddress, tokenId, amount);
    }

    /// @notice public Lock part of deposit to a called smart contract, for internal use in same proxy
    /// @param user address
    /// @param tokenContractAddress address : ERC1155 smart contract
    /// @param tokenId uint256 : tokenId of ERC1155
    /// @param amount uint256 amount to lock
    /// @param lockedFor uint256 lockedId
    function internalLockDeposit_V2(
        address user,
        address tokenContractAddress,
        uint256 tokenId,
        uint256 amount,
        uint256 lockedFor
    ) public {
        _lockDeposit_V2(user, tokenContractAddress, tokenId, amount, lockedFor);
    }

    /// @notice public Unlock part of deposit to a called smart contract, for internal use in same proxy
    /// @param user address
    /// @param tokenContractAddress address : ERC1155 smart contract
    /// @param tokenId uint256 : tokenId of ERC1155
    /// @param amount uint256 amount to lock
    /// @param lockedFor uint256 lockedId
    function internalUnLockDeposit_V2(
        address user,
        address tokenContractAddress,
        uint256 tokenId,
        uint256 amount,
        uint256 lockedFor
    ) public {
        _unlockDeposit_V2(user, tokenContractAddress, tokenId, amount, lockedFor);
    }

    /// @notice public transfer depot locked, for internal use in same proxy
    /// @param lockedFor uin256 identity of locked requested
    /// @param from address of owner
    /// @param to address of receiver
    /// @param tokenContractAddress address of token contract
    /// @param tokenId uint256 id of token
    /// @param amount uint256 number of token
    /// @param keepLock bool , true if the transfer want to keep tocken locked
    /// @param data bytes additional data for transfer
    function internalTransferDepotLocked_V2(
        uint256 lockedFor,
        address from,
        address to,
        address tokenContractAddress,
        uint256 tokenId,
        uint256 amount,
        bool keepLock,
        bytes memory data
    ) public {
        _transferDepotLocked_V2(
            lockedFor,
            from,
            to,
            tokenContractAddress,
            tokenId,
            amount,
            keepLock,
            data
        );

        emit LogTransferDepotLocked_V2(
            lockedFor,
            from,
            to,
            tokenContractAddress,
            tokenId,
            amount,
            keepLock,
            data
        );
    }

    /// @notice public transfer depot, for internal use in same proxy
    /// @param from address of owner
    /// @param to address of receiver
    /// @param tokenContractAddress address of token contract
    /// @param tokenId uint256 id of token
    /// @param amount uint256 number of token
    /// @param data bytes additional data for transfer
    function internalTransferDepot_V2(
        address from,
        address to,
        address tokenContractAddress,
        uint256 tokenId,
        uint256 amount,
        bytes memory data
    ) public {
        _transferDepot_V2(
            from,
            to,
            tokenContractAddress,
            tokenId,
            amount,
            data
        );


        emit LogTransferDepot_V2(
            from,
            to,
            tokenContractAddress,
            tokenId,
            amount,
            data
        );
    }

    /// @notice oracle can manually force token unlock
    /// @param user address
    /// @param tokenContractAddress address : ERC1155 smart contract
    /// @param tokenId uint256 : tokenId of ERC1155
    /// @param amount uint256 amount to lock
    /// @param lockedFor uint256 lockedId
    function oracleUnlock_V2(
        address user,
        address tokenContractAddress,
        uint256 tokenId,
        uint256 amount,
        uint256 lockedFor
    ) public delegatedSendIsOracle_V1 {
        _unlockDeposit_V2(user, tokenContractAddress, tokenId, amount, lockedFor);
    }
}