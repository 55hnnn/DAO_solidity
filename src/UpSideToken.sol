// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";

contract UpSideToken is ERC20, ERC20Burnable, ERC20Pausable, Ownable, ERC20Permit, ERC20Votes {
    constructor(address initialOwner)
        ERC20("UpSideToken", "UST")
        Ownable(initialOwner)
        ERC20Permit("UpSideToken"){}

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }

    function getVotes(address account) public view override whenNotPaused returns (uint256) {
        return super.getVotes(account);
    }

    function delegate(address delegatee) public override whenNotPaused {
        super.delegate(delegatee);
    }

    function exchangeToken() external payable whenNotPaused {
        require(msg.value > 0, "give me some ether");
        _mint(msg.sender, msg.value);
    }

    function exchangeEther(uint256 amount) external whenNotPaused {
        require(balanceOf(msg.sender) >= amount, "not enough token balance");
        burn(amount);
        address(msg.sender).call{value: amount}("");
    }

    // The following functions are overrides required by Solidity.

    function _update(address from, address to, uint256 value)
        internal
        override(ERC20, ERC20Pausable, ERC20Votes)
    {
        super._update(from, to, value);
    }

    function nonces(address owner)
        public
        view
        override(ERC20Permit, Nonces)
        returns (uint256)
    {
        return super.nonces(owner);
    }
}
