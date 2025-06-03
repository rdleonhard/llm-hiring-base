// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

/// @title TaskRegistry (uses one Revnet token for both gating & payment)
contract TaskRegistry {
    // This Revnet token does double-duty:
    // • You must hold ≥ MIN_TSK to propose
    // • When a task is accepted, that same token is transferred to Rob
    IERC20 public immutable TSK;   // The Revnet ERC-20 on Base
    address public immutable rob;  // Rob's address (payment recipient)

    // How many TSK you must hold in order to propose a task
    uint256 public constant MIN_TSK = 10 * 10**18; // 10 tokens (18 decimals)

    enum TaskStatus { Proposed, Accepted, Cancelled }
    struct Task {
        address proposer;
        string  descriptionCID;
        uint256 amount;      // how many TSK locked as payment
        TaskStatus status;
    }

    mapping(uint256 => Task) public tasks;
    uint256 public nextTaskId;

    event TaskProposed(
        uint256 indexed taskId,
        address indexed proposer,
        uint256 amount,
        string  descriptionCID
    );
    event TaskAccepted(
        uint256 indexed taskId,
        address indexed proposer,
        address indexed rob,
        uint256 amount
    );
    event TaskCancelled(
        uint256 indexed taskId,
        address indexed proposer
    );

    modifier onlyRob() {
        require(msg.sender == rob, "Only Rob can call this");
        _;
    }

    modifier holdsMinTSK() {
        require(
            TSK.balanceOf(msg.sender) >= MIN_TSK,
            "Need >= 10 TSK to propose"
        );
        _;
    }

    constructor(address _tskToken, address _rob) {
        TSK = IERC20(_tskToken);
        rob = _rob;
        nextTaskId = 1;
    }

    /// @notice Propose a new task. You must hold ≥ MIN_TSK in your wallet.
    /// @param descriptionCID  IPFS (or Arweave) CID pointing to full task details
    /// @param amount         How many TSK you're offering Rob if he accepts
    function proposeTask(string calldata descriptionCID, uint256 amount)
        external
        holdsMinTSK
    {
        require(amount > 0, "Payment must be > 0 TSK");
        // Must have approved this contract to pull `amount` tokens from caller
        require(
            TSK.allowance(msg.sender, address(this)) >= amount,
            "Approve TSK before calling"
        );

        // Pull `amount` TSK from proposer into this contract (escrow)
        bool ok = TSK.transferFrom(msg.sender, address(this), amount);
        require(ok, "TSK.transferFrom failed");

        tasks[nextTaskId] = Task({
            proposer:       msg.sender,
            descriptionCID: descriptionCID,
            amount:         amount,
            status:         TaskStatus.Proposed
        });

        emit TaskProposed(nextTaskId, msg.sender, amount, descriptionCID);
        nextTaskId++;
    }

    /// @notice Cancel a task you previously proposed (if Rob hasn't accepted yet)
    /// @param taskId  The ID of your task
    function cancelTask(uint256 taskId) external {
        Task storage t = tasks[taskId];
        require(t.proposer == msg.sender, "Not your task");
        require(t.status == TaskStatus.Proposed, "Already accepted/cancelled");

        uint256 refund = t.amount;
        t.amount = 0;
        t.status = TaskStatus.Cancelled;

        bool ok = TSK.transfer(msg.sender, refund);
        require(ok, "Refund transfer failed");

        emit TaskCancelled(taskId, msg.sender);
    }

    /// @notice Rob calls this to accept a proposed task. Escrowed TSK flows immediately.
    /// @param taskId  The ID of the task to accept
    function acceptTask(uint256 taskId) external onlyRob {
        Task storage t = tasks[taskId];
        require(t.status == TaskStatus.Proposed, "Task not open");

        t.status = TaskStatus.Accepted;
        uint256 payout = t.amount;
        t.amount = 0;

        bool ok = TSK.transfer(rob, payout);
        require(ok, "Payout transfer failed");

        emit TaskAccepted(taskId, t.proposer, rob, payout);
    }

    /// @notice Read a task's details:
    /// @return proposer The address of the proposer
    /// @return descriptionCID The CID of the task description
    /// @return amount The amount of TSK locked as payment
    /// @return status The status of the task
    function getTask(uint256 taskId)
        external
        view
        returns (
            address proposer,
            string memory descriptionCID,
            uint256 amount,
            TaskStatus status
        )
    {
        Task storage t = tasks[taskId];
        return (t.proposer, t.descriptionCID, t.amount, t.status);
    }
}
