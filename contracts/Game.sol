// SPDX-License-Identifier: GPL-3.0

pragma experimental ABIEncoderV2;
pragma solidity 0.8.10;

import "./Session/Session.sol";
import "./User.sol";

contract Game is Session, User {
    using SafeMath for uint;
    using SafeMath32 for uint32;
    using SafeMath16 for uint16;

    //вывод money
    fallback() external payable{}
    receive() external payable{}

    function withdrawDBT(address _to) public isOwner {
        DBT.transfer(_to, DBT.balanceOf(address(this)));
    }

    function withdrawBNB(address _to) public isOwner {
        payable(_to).transfer(address(this).balance);
    }
}
