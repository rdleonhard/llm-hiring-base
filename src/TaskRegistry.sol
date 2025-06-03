// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// Import OpenZeppelin’s ERC-20 interface
import "@openzeppelin-contracts/token/ERC20/IERC20.sol";

/// @title TaskRegistry (uses clientCoin as a Revnet token + taskCoin as payment)
contract TaskRegistry {
    IERC20 public clientCoin;   // Revnet token (CLC)
    IERC20 public taskCoin;     // Payment token (TSK)
    address public rob;         // Rob’s address

    uint256 public constant MIN_CLIENTCOIN = 10 * 10**18; // 10 CLC (18 decimals)

    enum TaskStatus { Proposed, Accepted, Cancelled }
    struct Task {
        address proposer;
        string descriptionCID;
        uint256 amountTSK;
        TaskStatus status;
    }

    mapping(uint256 => Task) public tasks;
    uint256 public nextTaskId;

    modifier onlyRob() {
        require(msg.sender == rob, "Only Rob can call this");
        _;
    }

    modifier holdsMinClientCoin() {
        require(clientCoin.balanceOf(msg.sender) >= MIN_CLIENTCOIN,
                "Need ≥ 10 clientCoin to propose");
        _;
    }

    event TaskProposed(
        uint256 indexed taskId,
        address indexed proposer,
        uint256 amountTSK,
        string descriptionCID
    );
    event TaskAccepted(
        uint256 indexed taskId,
        address indexed proposer,
        address indexed rob,
        uint256 amountTSK
    );
    event TaskCancelled(
        uint256 indexed taskId,
        address indexed proposer
    );

    constructor(
        address _clientCoin,
        address _taskCoin,
        address _rob
    ) {
        clientCoin = IERC20(_clientCoin);
        taskCoin   = IERC20(_taskCoin);
        rob        = _rob;
        nextTaskId = 1;
    }

    function proposeTask(
        string calldata descriptionCID,
        uint256 amountTSK
    ) external holdsMinClientCoin {
        require(amountTSK > 0, "Offer must be > 0 TSK");
        require(
            taskCoin.allowance(msg.sender, address(this)) >= amountTSK,
            "Approve taskCoin first"
        );

        // Transfer TSK from proposer → this contract (escrow)
        bool ok = taskCoin.transferFrom(msg.sender, address(this), amountTSK);
        require(ok, "TSK transfer failed");

        tasks[nextTaskId] = Task({
            proposer:       msg.sender,
            descriptionCID: descriptionCID,
            amountTSK:      amountTSK,
            status:         TaskStatus.Proposed
        });

        emit TaskProposed(nextTaskId, msg.sender, amountTSK, descriptionCID);
        nextTaskId++;
    }

    function cancelTask(uint256 taskId) external {
        Task storage t = tasks[taskId];
        require(t.proposer == msg.sender, "Not your task");
        require(t.status == TaskStatus.Proposed, "Not open");

        uint256 refund = t.amountTSK;
        t.amountTSK = 0;
        t.status = TaskStatus.Cancelled;

        bool ok = taskCoin.transfer(msg.sender, refund);
        require(ok, "Refund failed");

        emit TaskCancelled(taskId, msg.sender);
    }

    function acceptTask(uint256 taskId) external onlyRob {
        Task storage t = tasks[taskId];
        require(t.status == TaskStatus.Proposed, "Not open");

        t.status = TaskStatus.Accepted;
        uint256 payout = t.amountTSK;
        t.amountTSK = 0;

        bool ok = taskCoin.transfer(rob, payout);
        require(ok, "Transfer to Rob failed");

        emit TaskAccepted(taskId, t.proposer, rob, payout);
    }

    function getTask(uint256 taskId) external view returns (
        address proposer,
        string memory descriptionCID,
        uint256 amountTSK,
        TaskStatus status
    ) {
        Task storage t = tasks[taskId];
        return (t.proposer, t.descriptionCID, t.amountTSK, t.status);
    }
}
