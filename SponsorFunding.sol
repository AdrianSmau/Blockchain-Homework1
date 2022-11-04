// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "./Funding.sol";
import "./CrowdFunding.sol";

contract SponsorFunding is Funding {
    using SafeMath for uint256;
    using SafeMath16 for uint16;
    using Strings for uint256;

    uint16 private payrate;
    mapping(address => bool) private whitelist;

    constructor(uint16 _payrate) payable {
        payrate = _payrate;
    }

    modifier whitelistedOnly() {
        require(
            whitelist[msg.sender] == true,
            "This crowdfunder is not part of the whitelisted projects"
        );
        _;
    }

    modifier contractOnly() {
        address sender = _msgSender();
        uint256 len;

        assembly {
            len := extcodesize(sender)
        }

        require(
            len > 0,
            "Only CrowdFunding Contracts (non-EOA) can be sponsored!"
        );
        _;
    }

    // Function called by a CrowdFunding project in order to ask for a sponsorship
    function request_sponsorship() external contractOnly whitelistedOnly {
        CrowdFunding project = CrowdFunding(_msgSender());
        uint256 sponsorship_fund = (_msgSender().balance * payrate) / 100;

        require(
            address(this).balance >= sponsorship_fund,
            "Insufficient funds to sponsor this project!"
        );
        require(
            sponsorship_fund > 0,
            "The sponsorship fund sum cannot be zero!"
        );

        project.receive_sponsorship{value: sponsorship_fund}();
    }

    // A sponsor can fund this account here
    function deposit() external payable onlyOwner {
        require(
            msg.value > 0,
            "You cannot deposit 0 Wei to your sponsorship account!"
        );
    }

    // A sponsor can withdraw the funds from this contract here
    function withdraw(uint256 _amount) external onlyOwner {
        require(
            address(this).balance >= _amount,
            "You cannot withdraw past the sponsorship account balance!"
        );
        payable(owner()).transfer(_amount);
    }

    // Check sponsorship account's balance
    function balance() external view onlyOwner returns (uint256) {
        return address(this).balance;
    }

    // Update payrate percentage
    function update_payrate(uint16 _payrate) external onlyOwner {
        require(_payrate > 0, "The sponsorship payrate must be at least 1%!");
        payrate = _payrate;
    }

    // Whitelist a CrowdFunding project
    function whitelist_project(address _project_addr) external onlyOwner {
        whitelist[_project_addr] = true;
    }

    // Remove a project from the whitelist
    function blacklist_project(address _project_addr) external onlyOwner {
        whitelist[_project_addr] = false;
    }
}
