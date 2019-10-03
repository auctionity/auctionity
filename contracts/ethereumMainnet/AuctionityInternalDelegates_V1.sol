pragma solidity ^0.5.4;

import "./AuctionityLibrary_V1.sol";

contract AuctionityInternalDelegates_V1 is AuctionityLibrary_V1 {
    /// bytes4 => address
    bytes32 private constant INTERNAL_DELEGATES_V1_SLOT = keccak256("proxy.internal.delegates.v1");

    event LogInternalSelectorAdded_V1(bytes4 selector, address delegate);
    event LogInternalSelectorUpdated_V1(
        bytes4 selector,
        address delegate,
        address previousDelegate
    );
    event LogInternalSelectorRemoved_V1(bytes4 selector, address delegate);

    function getInternalDelegate_V1(bytes4 _selector) public returns (address _contractDelegate) {

        bytes32 _internalDelegate = INTERNAL_DELEGATES_V1_SLOT;
        bytes32 slot;
        assembly {
            slot := add(_internalDelegate, _selector)
            _contractDelegate := sload(slot)
        }
    }

    function _setInternalDelegate_V1(bytes4 _selector, address _contractDelegate) internal {
        bytes32 _internalDelegate = INTERNAL_DELEGATES_V1_SLOT;

        assembly {
            let slot := add(_internalDelegate, _selector)
            sstore(slot, _contractDelegate)
        }
    }

    function _callInternalDelegated_V1(
        bytes memory _calldata,
        address _fallback
    ) internal returns (
        uint returnPtr,
        uint returnSize
    ) {

        // Extract selector from provided data.
        uint32 _selector;

        assembly {
            _selector := mload(add(_calldata, 4))
        }

        // Get internal delegate address.
        address _delegate = getInternalDelegate_V1(bytes4(_selector));

        // Use fallback if not delegate.
        if (_delegate == address(0)) {
            _delegate = _fallback;
        }


        require(_delegate != address(0), "Internal function doesn't exist");

        // Delegate call, propagate result or revert.
        assembly {
            let result := delegatecall(
                gas,
                _delegate,
                add(_calldata, 0x20),
                mload(_calldata),
                0,
                0
            )

            returnSize := returndatasize
            returnPtr := mload(0x40)
            returndatacopy(returnPtr, 0, returnSize)

            if eq(result, 0) {
                revert(returnPtr, returnSize)
            }
        }

        return (returnPtr, returnSize);
    }

    function addInternalSelectors_V1(address _delegate, bytes4[] memory _selectors)
        public
    {
        require(
            delegatedSendIsContractOwner_V1(),
            "addInternalSelectors_V1 Contract owner"
        );

        require(_delegate != address(0), "delegate can't be zero address.");

        for (uint selectorIndex; selectorIndex < _selectors.length; selectorIndex++) {
            require(
                //delegates[_selectors[selectorIndex]] == address(0),
                getInternalDelegate_V1(_selectors[selectorIndex]) == address(0),
                "FuncId clash."
            );
            //delegates[_selectors[selectorIndex]] = _delegate;
            _setInternalDelegate_V1(_selectors[selectorIndex], _delegate);
            emit LogInternalSelectorAdded_V1(_selectors[selectorIndex], _delegate);
        }
    }

    function updateInternalSelectors_V1(address _delegate, bytes4[] memory _selectors)
        public
    {
        require(
            delegatedSendIsContractOwner_V1(),
            "updateInternalSelectors_V1 Contract owner"
        );

        require(_delegate != address(0), "delegate can't be zero address.");

        for (uint selectorIndex; selectorIndex < _selectors.length; selectorIndex++) {
            address delegate = getInternalDelegate_V1(_selectors[selectorIndex]);
            require(
                //delegates[_selectors[selectorIndex]] != address(0),
                delegate != address(0),
                "Selector does not exist."
            );
            //address previousDelegate = delegates[_selectors[selectorIndex]];
            address previousDelegate = delegate;
            //delegates[_selectors[selectorIndex]] = _delegate;
            _setInternalDelegate_V1(_selectors[selectorIndex], _delegate);
            emit LogInternalSelectorUpdated_V1(
                _selectors[selectorIndex],
                _delegate,
                previousDelegate
            );
        }
    }

    function removeInternalSelectors_V1(bytes4[] memory _selectors) public {
        require(
            delegatedSendIsContractOwner_V1(),
            "removeInternalSelectors_V1 Contract owner"
        );

        for (uint selectorIndex; selectorIndex < _selectors.length; selectorIndex++) {
            address delegate = getInternalDelegate_V1(_selectors[selectorIndex]);
            require(
                //delegates[_selectors[selectorIndex]] != address(0),
                delegate != address(0),
                "Selector does not exist."
            );
            //address previousDelegate = delegates[_selectors[selectorIndex]];
            address previousDelegate = delegate;
            //delete delegates[_selectors[selectorIndex]];
            _setInternalDelegate_V1(_selectors[selectorIndex], address(0));
            emit LogInternalSelectorRemoved_V1(
                _selectors[selectorIndex],
                previousDelegate
            );

        }
    }
}