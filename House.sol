pragma solidity ^0.8.7;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./IBlastPoints.sol";

contract House is Ownable {
    event PayoutEvent(address winner, uint amount);

    enum State {
        CLOSED,
        OPEN
    }

    using SafeERC20 for IERC20;

    IERC20 public gameToken;
    State public bettingState;

    uint private coinLimit;
    address public roulette;

    modifier betting(State state) {
        require(
            state == bettingState,
            "current betting state does not allow this"
        );
        _;
    }

    modifier onlyGame() {
        require(msg.sender == roulette, "only roulette can call this function");
        _;
    }

    constructor(
        address initialOwner,
        address _pointsOperator,
        address _BlastPointsAddress,
        address tokenAddress
    ) Ownable(initialOwner) {
        gameToken = IERC20(tokenAddress);
        bettingState = State.OPEN;

        // be sure to use the appropriate testnet/mainnet BlastPoints address
        // BlastPoints Testnet address: 0x2fc95838c71e76ec69ff817983BFf17c710F34E0
        // BlastPoints Mainnet address: 0x2536FE9ab3F511540F2f9e2eC2A805005C3Dd800

        IBlastPoints(_BlastPointsAddress).configurePointsOperator(
            _pointsOperator
        );
    }

    function setGameAddresses(address _roulette) external onlyOwner {
        roulette = _roulette;
    }

    function payout(
        address winner,
        uint amount
    ) external onlyGame betting(State.OPEN) {
        gameToken.safeTransfer(winner, amount);

        if (gameToken.balanceOf(address(this)) <= coinLimit) {
            bettingState = State.CLOSED;
        }

        emit PayoutEvent(winner, amount);
    }

    function openBetting() external onlyOwner betting(State.CLOSED) {
        bettingState = State.OPEN;
    }

    function closeBetting() external onlyOwner betting(State.OPEN) {
        bettingState = State.CLOSED;
    }

    function setCoinLimit(uint newLimit) external onlyOwner {
        coinLimit = newLimit;
    }

    function withdrawFunds(uint amount) external onlyOwner {
        gameToken.safeTransfer(owner(), amount);
    }

    function getCoinLimit() external view onlyOwner returns (uint) {
        return coinLimit;
    }

    function _transferOwner(address newOwner) external onlyOwner {
        transferOwnership(newOwner);
    }

    receive() external payable {}
}
