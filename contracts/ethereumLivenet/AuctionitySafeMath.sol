pragma solidity 0.4.23;

/**
 * @title SafeMath
 * @dev Math operations with safety checks that throw on error
 */
library AuctionitySafeMath {
  function safeMul(uint256 a, uint256 b) internal pure returns (uint256) {
    if (a == 0 || b == 0) {
      return 0;
    }
    uint256 c = a * b;
    require(c / a == b);
    return c;
  }
  
  function safeSub(uint256 a, uint256 b) internal pure returns (uint256) {
    require(b <= a);
    return a - b;
  }

  function safeSub64(uint64 a, uint64 b) internal pure returns (uint64) {
    require(b <= a);
    return a - b;
  }

  function safeAdd(uint256 a, uint256 b) internal pure returns (uint256) {
    uint256 c = a + b;
    require(c >= a);
    return c;
  }

  function safeAdd64(uint64 a, uint64 b) internal pure returns (uint64) {
    uint64 c = a + b;
    require(c >= a);
    return c;
  }

  function safeSub248(uint248 a, uint248 b) internal pure returns (uint248) {
    require(b <= a);
    return a - b;
  }

  function safeAdd248(uint248 a, uint248 b) internal pure returns (uint248) {
    uint248 c = a + b;
    require(c >= a);
    return c;
  }
}
