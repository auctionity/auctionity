pragma solidity ^0.5.4;

library RLPWriter {
    function toRlp(bytes memory _value)
        internal
        pure
        returns (bytes memory _bytes)
    {
        uint _valuePtr;
        uint _rplPtr;
        uint _valueLength = _value.length;

        assembly {
            _valuePtr := add(_value, 0x20)
            _bytes := mload(0x40) // Free memory ptr
            _rplPtr := add(_bytes, 0x20) // RLP first byte ptr
        }

        // [0x00, 0x7f]
        if (_valueLength == 1 && _value[0] <= 0x7f) {
            assembly {
                mstore(_bytes, 1) // Bytes size is 1
                mstore(_rplPtr, mload(_valuePtr)) // Set value as-is
                mstore(0x40, add(_rplPtr, 1)) // Update free ptr
            }
            return _bytes;
        }

        // [0x80, 0xb7]
        if (_valueLength <= 55) {
            assembly {
                mstore(_bytes, add(1, _valueLength)) // Bytes size
                mstore8(_rplPtr, add(0x80, _valueLength)) // RLP small string size
                mstore(0x40, add(add(_rplPtr, 1), _valueLength)) // Update free ptr
            }

            copy(_valuePtr, _rplPtr + 1, _valueLength);
            return _bytes;
        }

        // [0xb8, 0xbf]
        uint _lengthSize = uintMinimalSize(_valueLength);

        assembly {
            mstore(_bytes, add(add(1, _lengthSize), _valueLength)) // Bytes size
            mstore8(_rplPtr, add(0xb7, _lengthSize)) // RLP long string "size size"
            mstore(
                add(_rplPtr, 1),
                mul(_valueLength, exp(256, sub(32, _lengthSize)))
            ) // Bitshift to store the length only _lengthSize bytes
            mstore(0x40, add(add(add(_rplPtr, 1), _lengthSize), _valueLength)) // Update free ptr
        }

        copy(_valuePtr, _rplPtr + 1 + _lengthSize, _valueLength);
        return _bytes;
    }

    function toRlp(uint _value) internal pure returns (bytes memory _bytes) {
        uint _size = uintMinimalSize(_value);

        bytes memory _valueBytes = new bytes(_size);

        assembly {
            mstore(
                add(_valueBytes, 0x20),
                mul(_value, exp(256, sub(32, _size)))
            )
        }

        return toRlp(_valueBytes);
    }

    function toRlp(bytes[] memory _values)
        internal
        pure
        returns (bytes memory _bytes)
    {
        uint _ptr;
        uint _size;
        uint i;

        // compute data size
        for (; i < _values.length; ++i) _size += _values[i].length;

        // create rlp header
        assembly {
            _bytes := mload(0x40)
            _ptr := add(_bytes, 0x20)
        }

        if (_size <= 55) {
            assembly {
                mstore8(_ptr, add(0xc0, _size))
                _ptr := add(_ptr, 1)
            }
        } else {
            uint _size2 = uintMinimalSize(_size);

            assembly {
                mstore8(_ptr, add(0xf7, _size2))
                _ptr := add(_ptr, 1)
                mstore(_ptr, mul(_size, exp(256, sub(32, _size2))))
                _ptr := add(_ptr, _size2)
            }
        }

        // copy data
        for (i = 0; i < _values.length; ++i) {
            bytes memory _val = _values[i];
            uint _valPtr;

            assembly {
                _valPtr := add(_val, 0x20)
            }

            copy(_valPtr, _ptr, _val.length);

            _ptr += _val.length;
        }

        assembly {
            mstore(0x40, _ptr)
            mstore(_bytes, sub(sub(_ptr, _bytes), 0x20))
        }
    }

    function uintMinimalSize(uint _value) internal pure returns (uint _size) {
        for (; _value != 0; _size++) _value /= 256;
    }

    /*
    * @param src Pointer to source
    * @param dest Pointer to destination
    * @param len Amount of memory to copy from the source
    */
    function copy(uint src, uint dest, uint len) internal pure {
        // copy as many word sizes as possible
        for (; len >= 32; len -= 32) {
            assembly {
                mstore(dest, mload(src))
            }

            src += 32;
            dest += 32;
        }

        // left over bytes
        uint mask = 256 ** (32 - len) - 1;
        assembly {
            let srcpart := and(mload(src), not(mask)) // zero out src
            let destpart := and(mload(dest), mask) // retrieve the bytes
            mstore(dest, or(destpart, srcpart))
        }
    }
}
