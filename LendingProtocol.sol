// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/IERC20.sol";
import "./UserID.sol";


contract LendingContract {
    UserID private userID;
    mapping(address => mapping(address => uint)) public SuppliedTokeninWei;
    mapping(address => mapping(address => uint)) public BorrowedTokeninWei;

    event TokenDepositMade(
        address indexed accountAddress,
        address tokenAddress,
        uint amount
    );
    event TokenBorrowMade(
        address indexed accountAddress,
        address tokenAddress,
        uint amount
    );
    event TokenRepayMade(
        address indexed accountAddress,
        address tokenAddress,
        uint amount
    );
    event TokenWithdrawMade(
        address indexed accountAddress,
        address tokenAddress,
        uint amount
    );

    constructor(address _userIDaddress) {
        userID = UserID(_userIDaddress);
    }

    function supplyViaToken(uint _amount, address _tokenAddress) public {
        IERC20 token = IERC20(_tokenAddress);
        require(
            userID.getAccountScore(msg.sender) != 0,
            "User does not have user ID"
        );
        require(_amount > 0, "Amount must be greater than 0");
        require(
            token.balanceOf(msg.sender) >= _amount,
            "Insufficient token balance"
        );

        // Check that the contract has enough allowance to perform the transfer.
        // This also ensures that the token contract address is not zero because the EVM reverts with a 'divide by zero' error.
        require(
            token.allowance(msg.sender, address(this)) >= _amount,
            "Token is not approved"
        );

        // Perform the transfer and allow it to revert if anything goes wrong
        token.transferFrom(msg.sender, address(this), _amount);

        // Update the state to reflect the new supply
        SuppliedTokeninWei[msg.sender][_tokenAddress] += _amount;
        emit TokenDepositMade(msg.sender, _tokenAddress, _amount);
    }

    function borrowToken(uint _amount, address _tokenAddress) public {
        IERC20 token = IERC20(_tokenAddress);

        require(
            userID.getAccountScore(msg.sender) != 0,
            "User does not have user ID"
        );
        require(_amount > 0, "Amount must be greater than 0");

        uint userCreditScore = userID.getAccountScore(msg.sender);
        uint userMultiplier = getMultiplier(userCreditScore);
        uint maxiumumAllowwableBorrow = (SuppliedTokeninWei[msg.sender][
        _tokenAddress
        ] * userMultiplier) / 1e18;
        require(
            BorrowedTokeninWei[msg.sender][_tokenAddress] + _amount <=
            maxiumumAllowwableBorrow,
            "You cant borrow more than your limit"
        );
        BorrowedTokeninWei[msg.sender][_tokenAddress] += _amount;
        token.transferFrom(address(this), msg.sender, _amount);
        emit TokenBorrowMade(msg.sender, _tokenAddress, _amount);
    }

    function getMultiplier(uint _creditScore) public pure returns (uint) {
        if (_creditScore >= 360 && _creditScore < 400) {
            return 65 * (10 ** 16); // 0.65
        } else if (_creditScore >= 400 && _creditScore < 440) {
            return 7 * (10 ** 17); // 0.7
        } else if (_creditScore >= 440 && _creditScore <= 500) {
            return 75 * (10 ** 16); // 0.75
        } else {
            return 80 * (10 ** 16);
        }
    }

    function RepayToken(uint _amount, address _tokenAddress) public {
        IERC20 token = IERC20(_tokenAddress);

        require(
            userID.getAccountScore(msg.sender) != 0,
            "User does not have user ID"
        );
        require(_amount > 0, "Amount must be greater than 0");
        require(
            BorrowedTokeninWei[msg.sender][_tokenAddress] >= _amount,
            "Repaying more than borrowed amount"
        );
        BorrowedTokeninWei[msg.sender][_tokenAddress] -= _amount;
        token.transferFrom(msg.sender, address(this), _amount);
        emit TokenRepayMade(msg.sender, _tokenAddress, _amount);
    }

    function WithdrawToken(uint _amount, address _tokenAddress) public {
        IERC20 token = IERC20(_tokenAddress);

        require(
            userID.getAccountScore(msg.sender) != 0,
            "User does not have user ID"
        );
        require(_amount > 0, "Amount must be greater than 0");
        require(
            SuppliedTokeninWei[msg.sender][_tokenAddress] >= _amount,
            "Trying to withdraw more than supplied"
        );
        require(
            SuppliedTokeninWei[msg.sender][_tokenAddress] - _amount >=
            BorrowedTokeninWei[msg.sender][_tokenAddress] /
            getMultiplier(userID.getAccountScore(msg.sender)),
            "You can not withdraw this amount with the borrowed amount"
        );
        require(
            token.balanceOf(address(this)) >= _amount,
            "Not Enough Token in contract"
        );
        token.transfer(msg.sender, _amount);
        SuppliedTokeninWei[msg.sender][_tokenAddress] -= _amount;
        emit TokenWithdrawMade(msg.sender, _tokenAddress, _amount);
    }
}