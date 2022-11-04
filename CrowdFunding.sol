// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "./Funding.sol";
import "./FundingStatus.sol";
import "./SponsorFunding.sol";
import "./DistributeFunding.sol";

contract CrowdFunding is Funding {
    using SafeMath for uint256;
    using Strings for uint256;

    address private sponsor;
    uint256 private immutable funding_goal;
    address private last_contributor;

    struct Contributor {
        string first_name;
        string last_name;
        string email;
    }

    Contributor[] private contributors;
    mapping(address => Contributor) address_of_contributor;
    mapping(address => uint256) private contributor_donation;
    mapping(Status => string) internal statuses_to_string;

    Status private funding_status = Status.Unfunded;

    constructor(uint256 _funding_goal) {
        require(
            _funding_goal > 0,
            "You cannot have a CrowdFunding with no funding goal!"
        );
        funding_goal = _funding_goal;

        statuses_to_string[Status.Unfunded] = "Unfunded";
        statuses_to_string[Status.Prefunded] = "Prefunded";
        statuses_to_string[Status.Funded] = "Funded";
    }

    modifier withStatus(Status _status) {
        require(
            funding_status == _status,
            "Current status does not allow the called function's execution!"
        );
        _;
    }

    // This function assures the donation feaute, meaning through this function, one can donate to the project
    function deposit(
        string calldata _first_name,
        string calldata _last_name,
        string calldata _email
    ) external payable withStatus(Status.Unfunded) {
        require(msg.value > 0, "You must send at least 1 Wei!");
        address sender = _msgSender();

        // if it's their first donation
        if (contributor_donation[sender] == 0) {
            Contributor memory contributor = Contributor(
                _first_name,
                _last_name,
                _email
            );
            contributors.push(contributor);
            address_of_contributor[sender] = contributor;
        }
        contributor_donation[sender] = contributor_donation[sender].add(
            msg.value
        );
        last_contributor = sender;

        if (address(this).balance >= funding_goal) {
            funding_status = Status.Prefunded;
        }
    }

    // This function can be used either to withdraw the donation during Unfunded phase, or to withdraw the excess amount of funds (in correlation with funding goal) during Prefunded phase
    function withdraw_donation(uint256 _amount) external {
        require(
            contributor_donation[_msgSender()] >= _amount,
            "You cannot withdraw past the amount you've donated!"
        );
        require(_amount > 0, "You must withdraw at least 1 Wei!");
        require(
            funding_status != Status.Funded,
            "During the Funded phase, you cannot withdraw funds!"
        );

        address sender = _msgSender();

        if (funding_status == Status.Unfunded) {
            contributor_donation[sender] = contributor_donation[sender].sub(
                _amount
            );
            payable(sender).transfer(_amount);
        } else if (funding_status == Status.Prefunded) {
            if (sender == last_contributor) {
                require(
                    address(this).balance.sub(_amount) >= funding_goal,
                    "You cannot withdraw below the funding goal!"
                );

                contributor_donation[sender] = contributor_donation[sender].sub(
                    _amount
                );
                payable(sender).transfer(_amount);
            } else {
                revert(
                    "The withdrawal and receiving of funds is unavailable during this phase!"
                );
            }
        }
    }

    // One project reaches Prefunded phase, it can call a sponsor which whitelisted it in order to accquire sponsorship
    function request_sponsorship(address _sponsor_addr)
        external
        payable
        onlyOwner
        withStatus(Status.Prefunded)
    {
        SponsorFunding sponsor_funding = SponsorFunding(_sponsor_addr);
        sponsor_funding.request_sponsorship();
        sponsor = _sponsor_addr;
    }

    modifier requestedByProject() {
        require(
            tx.origin == owner(),
            "This sponsorhip was not requested by this project!"
        );
        _;
    }

    // Function through which the sponsor pays the project and the phase becomed Funded
    function receive_sponsorship() external payable requestedByProject {
        console.log("This contract is now sponsored!");
        funding_status = Status.Funded;
    }

    // Once project is funded, its funds can be transfered to a DistributeFunding contract in order to distribute the funds
    function transfer_funds_to_distribution(address _distribute_funding_addr)
        external
        onlyOwner
        withStatus(Status.Funded)
    {
        DistributeFunding distribute_funding = DistributeFunding(
            _distribute_funding_addr
        );

        distribute_funding.transfer_funds{value: address(this).balance}(
            owner()
        );
    }

    // A donor can check their contribution
    function check_my_contribution() external view returns (uint256) {
        return contributor_donation[_msgSender()];
    }

    // Utility function in order to see the funding progress
    function check_funding_progress() external view returns (string memory) {
        return
            string(
                string.concat(
                    "Progress is: ",
                    bytes(Strings.toString(address(this).balance)),
                    " Wei out of ",
                    bytes(Strings.toString(funding_goal)),
                    "!"
                )
            );
    }

    // Utility function in order to see the current phase
    function getStatusAsString() external view returns (string memory) {
        return statuses_to_string[funding_status];
    }
}
