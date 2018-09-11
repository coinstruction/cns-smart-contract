pragma solidity 0.4.24;

import "./TokenDeskProxySupport.sol";


contract TokenDeskProxy {
    TokenDeskProxySupport private tokenDeskProxySupport;
    uint256 public bonus;

    constructor(address _tokenDeskProxySupport, uint256 _bonus) public {
        require(_tokenDeskProxySupport != address(0));
        tokenDeskProxySupport = TokenDeskProxySupport(_tokenDeskProxySupport);
        bonus = _bonus;
    }

    function () public payable {
        tokenDeskProxySupport.buyTokens.value(msg.value)(msg.sender, msg.sender, bonus);
    }
}
