// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "./Funding.sol";
import "./CrowdFunding.sol";

contract DistributeFunding is Funding {
    using SafeMath for uint256;
    using SafeMath16 for uint16;
    using Strings for uint256;

    mapping(address => address) private manager_to_contract;
    mapping(address => uint256) private contract_to_payroll;
    mapping(address => mapping(address => uint16))
        private contract_to_payroll_distribution;
    mapping(address => uint16) private contract_to_total_distribution;
    mapping(address => address[]) private contract_to_paid_beneficiaries;

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

    // Function that receives funds from a Funded project in order to distribute them
    function transfer_funds(address _manager) external payable contractOnly {
        manager_to_contract[_manager] = _msgSender();
        contract_to_payroll[_msgSender()] = msg.value;
    }

    modifier managerOnly() {
        require(
            contract_to_payroll[manager_to_contract[_msgSender()]] > 0,
            "You must be a project manager and your project must have their funds transfered!"
        );
        _;
    }

    modifier beneficiaryAlreadyPaid(address _manager, address _beneficiary) {
        require(
            !is_beneficiary_paid(manager_to_contract[_manager], _beneficiary),
            "The chosen beneficiary has already been paid!"
        );
        _;
    }

    // Here, a project manager can add a beneficiary in order to distribute the donations
    function add_beneficiary(address _beneficiary, uint16 _percent)
        external
        managerOnly
        beneficiaryAlreadyPaid(_msgSender(), _beneficiary)
    {
        require(_percent > 0, "Percent cannot be zero!");
        require(_percent < 101, "Percent cannot exceed 100!");
        require(
            contract_to_total_distribution[manager_to_contract[_msgSender()]]
                .add(_percent) < 101,
            "Total distribution percentage cannot exceed 100!"
        );

        // We update the manager's contract payroll mapping in order to attribute the beneficiary a given percentage
        contract_to_payroll_distribution[manager_to_contract[_msgSender()]][
            _beneficiary
        ] = _percent;

        // The total sum of percentage distributions increases
        contract_to_total_distribution[
            manager_to_contract[_msgSender()]
        ] = contract_to_total_distribution[manager_to_contract[_msgSender()]]
            .add(_percent);
    }

    // A beneficiary's rightful percentage can be updated here
    function update_percentage_of_beneficiary(
        address _beneficiary,
        uint16 _percent
    ) external managerOnly beneficiaryAlreadyPaid(_msgSender(), _beneficiary) {
        require(
            contract_to_payroll_distribution[manager_to_contract[_msgSender()]][
                _beneficiary
            ] > 0,
            "Chosen beneficiary was not added to your project! Add them before attempting!"
        );

        // Check if the updated total percentage distribution sum exceeds 100%
        contract_to_total_distribution[
            manager_to_contract[_msgSender()]
        ] = contract_to_total_distribution[manager_to_contract[_msgSender()]]
            .sub(
                contract_to_payroll_distribution[
                    manager_to_contract[_msgSender()]
                ][_beneficiary]
            );
        require(
            contract_to_total_distribution[manager_to_contract[_msgSender()]]
                .add(_percent) < 101,
            "The attempted total distribution exceeds 100%!"
        );

        // We update the manager's contract payroll mapping in order to attribute the beneficiary a given percentage
        contract_to_payroll_distribution[manager_to_contract[_msgSender()]][
            _beneficiary
        ] = _percent;

        // The total sum of percentage distributions gets updated
        contract_to_total_distribution[
            manager_to_contract[_msgSender()]
        ] = contract_to_total_distribution[manager_to_contract[_msgSender()]]
            .add(_percent);
    }

    // A beneficiary of a certain manager's project can withdraw their rightful percentage of the total sum here
    function withdraw_benefits(address _manager)
        external
        beneficiaryAlreadyPaid(_manager, _msgSender())
    {
        require(
            contract_to_payroll_distribution[manager_to_contract[_manager]][
                _msgSender()
            ] > 0,
            "You are not a beneficiary of the chosen manager's project!"
        );

        // The beneficiary is paid
        payable(_msgSender()).transfer(
            (contract_to_payroll_distribution[manager_to_contract[_manager]][
                _msgSender()
            ] * contract_to_payroll[manager_to_contract[_manager]]) / 100
        );

        // The beneficiary is marked as paid
        contract_to_paid_beneficiaries[manager_to_contract[_manager]].push(
            _msgSender()
        );
    }

    function is_beneficiary_paid(address _project_addr, address _beneficiary)
        internal
        view
        returns (bool)
    {
        for (
            uint256 i = 0;
            i < contract_to_paid_beneficiaries[_project_addr].length;
            i++
        ) {
            if (
                _beneficiary == contract_to_paid_beneficiaries[_project_addr][i]
            ) {
                return true;
            }
        }
        return false;
    }

    // A beneficiary can see its status in correlation with a project's manager here
    function see_my_status(address _manager)
        external
        view
        returns (string memory)
    {
        return
            string(
                string.concat(
                    "Are you already paid?: ",
                    is_beneficiary_paid(
                        manager_to_contract[_manager],
                        _msgSender()
                    )
                        ? bytes("true")
                        : bytes("false"),
                    ", your percentage being: ",
                    bytes(
                        Strings.toString(
                            contract_to_payroll_distribution[
                                manager_to_contract[_manager]
                            ][_msgSender()]
                        )
                    ),
                    "%!"
                )
            );
    }
}
