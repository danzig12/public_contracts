pragma solidity ^0.8.7;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./IHouse.sol";
import "./IBlast.sol";
import "./IBlastPoints.sol";

contract Roulette is Ownable {
    using SafeERC20 for IERC20;
    address public house;
    IERC20 public gameToken;

    uint private maxCoinBet;

    IBlast public constant BLAST =
        IBlast(0x4300000000000000000000000000000000000002);

    struct Bet {
        uint number;
        uint wager;
    }

    mapping(address => uint) private blockNumbers;
    mapping(address => bytes32) private betHashes;

    event PlayerBet(
        address player,
        uint randomNumber,
        uint winnings,
        bytes32 futureBlockhash
    );

    event PlayerBetCount(address player, uint totalBet);

    modifier IsHuman() {
        require(msg.sender == tx.origin, "function caller must be a human");
        _;
    }

    modifier HasBlockNumber() {
        require(
            blockNumbers[msg.sender] > 0,
            "must store block number before placing bet"
        );
        _;
    }

    constructor(
        address initialOwner,
        address _BlastPointsAddress,
        address _pointsOperator,
        address tokenAddress
    ) Ownable(initialOwner) {
        //MAX BET
        maxCoinBet = 720000000000000000000 ether;
        gameToken = IERC20(tokenAddress);
        IBlastPoints(_BlastPointsAddress).configurePointsOperator(
            _pointsOperator
        );
        BLAST.configureClaimableGas();
    }

    function setHouse(address _house) external onlyOwner {
        house = _house;
    }

    function commitToBet(
        Bet[] calldata bets,
        uint totalWager
    ) external payable {
        gameToken.safeTransferFrom(msg.sender, address(house), totalWager);

        checkBetsValid(bets, totalWager);

        blockNumbers[msg.sender] = block.number;
        betHashes[msg.sender] = keccak256(abi.encode(bets));

        emit PlayerBetCount(msg.sender, totalWager);
    }

    function revealBet(Bet[] calldata bets) external IsHuman HasBlockNumber {
        bytes32 betHash = keccak256(abi.encode(bets));

        bytes32 futureBlockhash = blockhash(blockNumbers[msg.sender]);
        blockNumbers[msg.sender] = 0;

        uint randomNumber = uint(keccak256(abi.encode(futureBlockhash))) % 38;
        uint winnings = 0;

        if (futureBlockhash != 0) {
            // ensure they havent just waited 256 blocks to get 0
            for (uint i = 0; i < bets.length; i++) {
                if (bets[i].number == randomNumber) {
                    winnings = bets[i].wager * 36;

                    if (betHash == betHashes[msg.sender]) {
                        IHouse(house).payout(msg.sender, winnings);
                    }

                    break; // prevent multiple wins with same number
                }
            }
        }

        emit PlayerBet(msg.sender, randomNumber, winnings, futureBlockhash);

        betHashes[msg.sender] = 0;
    }

    function checkBetsValid(Bet[] calldata bets, uint totalWager) internal {
        uint[38] memory playersMax;
        uint correctWager = 0;

        for (uint i = 0; i < bets.length; i++) {
            playersMax[bets[i].number] += bets[i].wager;
            correctWager += bets[i].wager;

            if (playersMax[bets[i].number] > maxCoinBet) {
                revert("Bet above max");
            }
        }

        if (correctWager > totalWager) {
            revert("Wager is not valid");
        }
    }

    function _transferOwner(address newOwner) external onlyOwner {
        transferOwnership(newOwner);
    }

    function updateMaxCoin(uint _maxCoinBet) external onlyOwner {
        maxCoinBet = _maxCoinBet;
    }

    function claimMyContractsGas() external onlyOwner {
        BLAST.claimAllGas(address(this), msg.sender);
    }
}
