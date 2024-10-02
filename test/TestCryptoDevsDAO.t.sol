// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import { Test } from "forge-std/Test.sol";
import { CryptoDevsDAO } from "../src/CryptoDevsDAO.sol";
import { CryptoDevsNFT } from "../src/CryptoDevsNFT.sol";
import { FakeNFTMarketplace } from "../src/FakeNFTMarketplace.sol";

contract TestCryptoDevsDAO is Test {
    CryptoDevsDAO dao;
    CryptoDevsNFT nft;
    FakeNFTMarketplace marketplace;
    address user1;
    address user2;

    function setUp() public {
        nft = new CryptoDevsNFT();
        marketplace = new FakeNFTMarketplace();
        dao = new CryptoDevsDAO(address(marketplace), address(nft)); 

        // set up users with some ETH
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");

        // Fund users
        vm.deal(user1, 10 ether);
        vm.deal(user2, 10 ether);

        // mint some NFTs to user 1
        vm.startPrank(user1);
        nft.mint();
        nft.mint();
        vm.stopPrank();

        // Propose a new proposal
        vm.prank(user1);
        dao.createProposal(0);
    }

    function testVoteOnProposal() public {
        // check inital state
        (,,uint256 yayVotes, uint256 nayVotes,) = dao.getProposal(0);
        assertEq(yayVotes, 0);
        assertEq(nayVotes, 0);

        // Vote on the proposal with 2 NFTs
        vm.startPrank(user1);
        dao.voteOnProposal(0, CryptoDevsDAO.Vote.YAY);

        // Check it's been counted
        (,,yayVotes, nayVotes,) = dao.getProposal(0);
        assertEq(yayVotes, 2);
        assertEq(nayVotes, 0);
        vm.stopPrank();
    } 

    function testCannotVoteTwice() public {
        vm.startPrank(user1);
        dao.voteOnProposal(0, CryptoDevsDAO.Vote.YAY);

        vm.expectRevert(CryptoDevsDAO.CrypotDevsDAO__ALREADY_VOTED.selector);
        dao.voteOnProposal(0, CryptoDevsDAO.Vote.YAY);
        vm.stopPrank();
    }

    function testVoteNayOnProposal() public {   
        vm.startPrank(user2);
        nft.mint();
        vm.stopPrank(); 

        vm.startPrank(user2);
        dao.voteOnProposal(0, CryptoDevsDAO.Vote.NAY);

        (,, uint256 yayVotes, uint256 nayVotes,) = dao.getProposal(0);
        assertEq(nayVotes, 1);
        assertEq(yayVotes, 0);
        vm.stopPrank();
    }
}