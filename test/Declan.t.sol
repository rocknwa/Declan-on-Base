// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "../src/Declan.sol"; // adjust the import path as needed

contract DeclanTest is Test {
    Declan public declan;

    // Test addresses for different roles.
    address gigOwner = address(0x1);
    address verifiedFreelancer = address(0x2);
    address nonVerifiedFreelancer = address(0x3);
    address contractOwner; // owner of Declan (will be msg.sender from deployment)
    
    // Constants used in tests
    uint256 initialBalance = 100 ether;
    uint256 feePercentage = 2; // 2%

    function setUp() public {
        // Save the deployer as the contract owner.
        contractOwner = address(this);
        
        // Fund the test addresses.
        vm.deal(gigOwner, initialBalance);
        vm.deal(verifiedFreelancer, initialBalance);
        vm.deal(nonVerifiedFreelancer, initialBalance);

        // Deploy the Declan contract.
        declan = new Declan();

        // Setup gig owner account (must be verified to create gigs).
        vm.prank(gigOwner);
        declan.createGigOwnerAccount("GigOwner1", gigOwner, "Company1", true, 5);

        // Setup a verified freelancer account.
        vm.prank(verifiedFreelancer);
        string[] memory skills = new string[](1);
        skills[0] = "Solidity";
        string[] memory categories = new string[](1);
        categories[0] = "Blockchain";
        declan.createFreelancerAccount(
            "Freelancer1",
            "http://portfolio.freelancer1.com",
            skills,
            categories,
            true, // verified
            4,
            "freelancer1@example.com",
            "USA",
            1
        );

        // Setup a non-verified freelancer account.
        vm.prank(nonVerifiedFreelancer);
        string[] memory skillsNonVer = new string[](1);
        skillsNonVer[0] = "Web2";
        string[] memory categoriesNonVer = new string[](1);
        categoriesNonVer[0] = "Development";
        declan.createFreelancerAccount(
            "NonVerified",
            "http://nonverified.com",
            skillsNonVer,
            categoriesNonVer,
            false, // not verified
            0,
            "nonverified@example.com",
            "USA",
            0
        );
    }

    ///////////////////////////////
    // Gig Creation Tests
    ///////////////////////////////

    function testCreateGigAsVerifiedGigOwner() public {
        uint256 budget = 1 ether;
        uint256 timeline = 7 days;

        // Call as gigOwner (who is verified) should succeed.
        vm.prank(gigOwner);
        uint256 gigId = declan.createGig("owner@example.com", "Test Gig", "Test description", timeline, budget);

        (
            uint256 id,
            address ownerAddress,
            ,
            ,
            ,
            string memory description,
            uint256 gigTimeline,
            uint256 deadline,
            uint256 storedBudget,
            bool featureGig,
            Declan.GigStatus status,
            address escrower,
            uint256 escrowAmount,
            uint256 warningCount
        ) = declan.gigs(gigId);

        assertEq(id, gigId, "Gig ID mismatch");
        assertEq(ownerAddress, gigOwner, "Incorrect gig owner address");
        assertEq(storedBudget, budget, "Budget not stored correctly");
        assertEq(gigTimeline, timeline, "Timeline not stored correctly");
        assertEq(description, "Test description", "Description mismatch");
        assertEq(escrowAmount, 0, "Escrow amount mismatch");
        assertEq(featureGig, false, "Feature gig should be false");
        assertEq(warningCount, 0, "Warning count should be zero");
        assertEq(escrower, address(declan), "Escrower should be zero address");
        assertEq(deadline, block.timestamp + timeline, "Deadline mismatch");
        assertEq(uint256(status), uint256(Declan.GigStatus.Open), "Gig should be open");
        // Additional assertions about deadline can be added if desired.
    }

    function testCreateGigRevertsForNonGigOwner() public {
        uint256 budget = 1 ether;
        uint256 timeline = 7 days;

        // verifiedFreelancer is not a gig owner. Expect revert.
        vm.prank(verifiedFreelancer);
        vm.expectRevert("Only gig owners can create gigs");
        declan.createGig("owner@example.com", "Test Gig", "Description", timeline, budget);
    }

    ///////////////////////////////
    // Bid Placement Tests
    ///////////////////////////////

    function testPlaceBidSuccess() public {
        uint256 budget = 1 ether;
        uint256 timeline = 7 days;

        // First, create a gig from a valid gig owner.
        vm.prank(gigOwner);
        uint256 gigId = declan.createGig("owner@example.com", "Test Gig", "Description", timeline, budget);

        // Then, a verified freelancer places a bid.
        uint256 bidAmount = 1 ether; // must be >= budget
        vm.prank(verifiedFreelancer);
        declan.placeBid(gigId, bidAmount);

        // Retrieve gig status after bidding.
        (, , , , , , , , , , Declan.GigStatus status, , , ) = declan.gigs(gigId);
        assertEq(uint256(status), uint256(Declan.GigStatus.BidPlaced), "Gig status should update to BidPlaced");
    }

    function testPlaceBidRevertsWhenBidTooLow() public {
        uint256 budget = 1 ether;
        uint256 timeline = 7 days;

        // Create a gig.
        vm.prank(gigOwner);
        uint256 gigId = declan.createGig("owner@example.com", "Test Gig", "Description", timeline, budget);

        // Attempt to place a bid lower than the required budget.
        uint256 bidAmount = 0.5 ether;
        vm.prank(verifiedFreelancer);
        vm.expectRevert("Bid amount must be greater than or equal to gig budget");
        declan.placeBid(gigId, bidAmount);
    }

    function testPlaceBidRevertsForNonVerifiedFreelancer() public {
        uint256 budget = 1 ether;
        uint256 timeline = 7 days;
        
        // Create a gig.
        vm.prank(gigOwner);
        uint256 gigId = declan.createGig("owner@example.com", "Test Gig", "Description", timeline, budget);

        // Non-verified freelancer should not be allowed to place a bid.
        uint256 bidAmount = 1 ether;
        vm.prank(nonVerifiedFreelancer);
        vm.expectRevert("Freelancer must be verified to perform this action");
        declan.placeBid(gigId, bidAmount);
    }

    ///////////////////////////////
    // Accept Bid & Escrow Tests
    ///////////////////////////////

    function testAcceptBidSuccess() public {
        uint256 budget = 1 ether;
        uint256 timeline = 7 days;
        
        // Create a gig.
        vm.prank(gigOwner);
        uint256 gigId = declan.createGig("owner@example.com", "Test Gig", "Description", timeline, budget);

        // Verified freelancer places a bid.
        uint256 bidAmount = 1 ether;
        vm.prank(verifiedFreelancer);
        declan.placeBid(gigId, bidAmount);

        // Gig owner accepts the bid.
        vm.prank(gigOwner);
        declan.acceptBid{value: budget}(gigId, 0);

        (, , , address assignedFreelancer, , , , , , , Declan.GigStatus status, , , ) = declan.gigs(gigId);
        assertEq(uint256(status), uint256(Declan.GigStatus.WIP), "Gig status should update to WIP");
        assertEq(assignedFreelancer, verifiedFreelancer, "Freelancer not assigned correctly");
    }

    function testAcceptBidRevertsForInsufficientEscrow() public {
        uint256 budget = 1 ether;
        uint256 timeline = 7 days;

        // Create a gig and let a verified freelancer place a bid.
        vm.prank(gigOwner);
        uint256 gigId = declan.createGig("owner@example.com", "Test Gig", "Description", timeline, budget);
        uint256 bidAmount = 1 ether;
        vm.prank(verifiedFreelancer);
        declan.placeBid(gigId, bidAmount);

        // Attempt to accept the bid with less than required msg.value.
        vm.prank(gigOwner);
        vm.expectRevert("Insufficient escrow amount");
        declan.acceptBid{value: 0.5 ether}(gigId, 0);
    }

    ///////////////////////////////
    // Gig Completion Flow Tests
    ///////////////////////////////

    function testCompleteAndConfirmGigFlow() public {
        uint256 budget = 1 ether;
        uint256 timeline = 7 days;
        
        // Step 1: Create gig.
        vm.prank(gigOwner);
        uint256 gigId = declan.createGig("owner@example.com", "Test Gig", "Description", timeline, budget);

        // Step 2: Place bid.
        uint256 bidAmount = 1 ether;
        vm.prank(verifiedFreelancer);
        declan.placeBid(gigId, bidAmount);

        // Step 3: Accept bid.
        vm.prank(gigOwner);
        declan.acceptBid{value: budget}(gigId, 0);

        // Step 4: Freelancer completes the gig.
        vm.prank(verifiedFreelancer);
        declan.completeGig(gigId);

        // Step 5: Confirm gig by gig owner.
        // Record freelancer balance before confirmation.
        uint256 balanceBefore = verifiedFreelancer.balance;
        vm.prank(gigOwner);
        declan.confirmGig(gigId);
        
        // Calculate expected payout (bid amount minus fee).
        uint256 fee = (bidAmount * feePercentage) / 100;
        uint256 expectedPayout = bidAmount - fee;
        uint256 balanceAfter = verifiedFreelancer.balance;
        assertEq(balanceAfter, balanceBefore + expectedPayout, "Freelancer did not receive correct payout");
    }

    ///////////////////////////////
    // Deadline & Reporting Tests
    ///////////////////////////////

    function testExtendDeadline() public {
        uint256 budget = 1 ether;
        uint256 timeline = 7 days;
        
        // Create a gig.
        vm.prank(gigOwner);
        uint256 gigId = declan.createGig("owner@example.com", "Test Gig", "Description", timeline, budget);

        (, , , , , , , uint256 initialDeadline, , , , , , uint256 initialWarning) = declan.gigs(gigId);
        
        // Extend the deadline.
        uint256 extension = 1 days;
        vm.prank(gigOwner);
        declan.extendDeadline(gigId, extension);
        (, , , , , , , uint256 newDeadline, , , , , , uint256 newWarning) = declan.gigs(gigId);
        
        assertEq(newDeadline, initialDeadline + extension, "Deadline extension failed");
        assertEq(newWarning, initialWarning + 1, "Warning count not incremented");
    }

    function testReportGigWIPCase() public {
        // For a gig in WIP state with three deadline extensions (warningCount == 3),
        // reporting should transfer the escrowed funds to the gig owner.

        uint256 budget = 1 ether;
        uint256 timeline = 7 days;
        
        // Create gig.
        vm.prank(gigOwner);
        uint256 gigId = declan.createGig("owner@example.com", "Test Gig", "Description", timeline, budget);

        // Verified freelancer places a bid.
        uint256 bidAmount = 1 ether;
        vm.prank(verifiedFreelancer);
        declan.placeBid(gigId, bidAmount);

        // Accept bid.
        vm.prank(gigOwner);
        declan.acceptBid{value: budget}(gigId, 0);

        // Extend deadline three times.
        for (uint i = 0; i < 3; i++) {
            vm.prank(gigOwner);
            declan.extendDeadline(gigId, 1 days);
        }

        // Ensure warningCount is now 3.
        (, , , , , , , , , , , , , uint256 warnings) = declan.gigs(gigId);
        assertEq(warnings, 3, "Warning count should be 3");

        // Record gig owner’s balance.
        uint256 ownerBalanceBefore = gigOwner.balance;
        vm.prank(gigOwner);
        declan.reportGig(gigId);
        uint256 ownerBalanceAfter = gigOwner.balance;

        // In WIP state, reporting sends the entire escrow (bidAmount) to the gig owner.
        assertEq(ownerBalanceAfter, ownerBalanceBefore + bidAmount, "Gig owner did not receive escrow on report");
    }

    function testReportGigCompletedCase() public {
    uint256 budget = 1 ether;
    uint256 timeline = 7 days;

    // Step 1: Create gig.
    vm.prank(gigOwner);
    uint256 gigId = declan.createGig("owner@example.com", "Test Gig", "Description", timeline, budget);

    // Step 2: Place bid.
    uint256 bidAmount = 1 ether;
    vm.prank(verifiedFreelancer);
    declan.placeBid(gigId, bidAmount);

    // Step 3: Accept bid with escrow.
    vm.prank(gigOwner);
    declan.acceptBid{value: budget}(gigId, 0);

    // Step 4: Extend deadline 3 times (to trigger warning threshold).
    for (uint i = 0; i < 3; i++) {
        vm.prank(gigOwner);
        declan.extendDeadline(gigId, 1 days);
    }

    // Step 5: Freelancer completes the gig.
    vm.prank(verifiedFreelancer);
    declan.completeGig(gigId);

    // Confirm gig is in `Completed` status.
    (, , , , , , , , , , Declan.GigStatus statusBefore, , , ) = declan.gigs(gigId);
    assertEq(uint256(statusBefore), uint256(Declan.GigStatus.Completed), "Gig should be marked Completed");

    // Step 6: Report gig (after 3 extensions + Completed state).
    uint256 freelancerBalanceBefore = verifiedFreelancer.balance;
    vm.prank(verifiedFreelancer);
    declan.reportGig(gigId);
    //uint256 freelancerBalanceAfter = verifiedFreelancer.balance;

    // Since gig was marked Completed, funds go to the freelancer (minus fee).
    uint256 fee = (bidAmount * feePercentage) / 100;
    uint256 expectedPayout = bidAmount - fee;

    uint256 freelancerBalanceAfter = verifiedFreelancer.balance;
          
    assertEq(freelancerBalanceAfter, freelancerBalanceBefore + expectedPayout, "Freelancer did not receive correct payout after report");
}


    ///////////////////////////////
    // Fee Withdrawal & Freelancer Updates Tests
    ///////////////////////////////

    function testWithdrawFees() public {
        // Setup a gig to collect fees.
        uint256 budget = 1 ether;
        uint256 timeline = 7 days;
        
        // Create gig.
        vm.prank(gigOwner);
        uint256 gigId = declan.createGig("owner@example.com", "Test Gig", "Description", timeline, budget);
        
        // Verified freelancer places a bid.
        uint256 bidAmount = 1 ether;
        vm.prank(verifiedFreelancer);
        declan.placeBid(gigId, bidAmount);

        // Accept bid.
        vm.prank(gigOwner);
        declan.acceptBid{value: budget}(gigId, 0);

        // Freelancer completes the gig.
        vm.prank(verifiedFreelancer);
        declan.completeGig(gigId);

        // Confirm gig to trigger fee collection.
        vm.prank(gigOwner);
        declan.confirmGig(gigId);

        // At this point fees should have been collected in the contract.
        uint256 feesCollected = declan.collectedFees();
        assertGt(feesCollected, 0);

        // Withdraw fees from the contract.
        // Withdraw call is restricted to the contract owner.
        uint256 balanceBefore = contractOwner.balance;
        // We call as the owner (address(this) since the test contract deployed Declan).
        vm.prank(contractOwner);
        declan.withdrawFees();
        uint256 balanceAfter = contractOwner.balance;
        assertEq(declan.collectedFees(), 0, "Fees were not reset to zero after withdrawal");
        assertGe(balanceAfter, balanceBefore + feesCollected, "Owner did not receive correct fee amount");
    }

  function testVerifyAndUpdateFreelancer() public {
    // Check that the non-verified freelancer is indeed not verified.
    (
        ,
        ,
        ,
        bool verified,
        ,
        ,
        ,
        
    ) = declan.freelancers(nonVerifiedFreelancer);
    assertFalse(verified, "Freelancer should not be verified initially");

    // Suppose a gig owner verifies the freelancer.
    vm.prank(gigOwner);
    declan.verifyFreelancer(nonVerifiedFreelancer, 3);

    // Re-read the freelancer data from storage.
    (
        ,
         ,
        ,
        bool verifiedUpdated,
        uint32 starsUpdated,
        ,
        ,
    
    ) = declan.freelancers(nonVerifiedFreelancer);
    assertTrue(verifiedUpdated, "Freelancer verification failed");
    assertEq(starsUpdated, 3, "Stars not updated correctly");

    // Now test updating freelancer data.
    // Note: Dynamic array updates (skills) are not returned by the public getter.
    string[] memory newSkills = new string[](1);
    newSkills[0] = "UpdatedSkill";
    vm.prank(nonVerifiedFreelancer);
    declan.updateFreelancer(nonVerifiedFreelancer, "http://updated-url.com", newSkills, 5);

    (
        , 
        ,
        string memory portfolioURLAfter,
         ,
        uint32 starsAfter,
        ,
        ,
        
    ) = declan.freelancers(nonVerifiedFreelancer);
    assertEq(portfolioURLAfter, "http://updated-url.com", "Portfolio URL not updated");
    // The dynamic array 'skills' isn't available via the public getter.
    assertEq(starsAfter, 5, "Stars not updated correctly");
}

    function testGigOwnerAccountCreation() public {
        // Test creating a gig owner account.
        vm.prank(gigOwner);
        declan.createGigOwnerAccount("NewGigOwner", gigOwner, "NewCompany", true, 5);

        // Check if the gig owner account was created successfully.
        (string memory name, , string memory companyName, bool verified, uint32 stars) = declan.gigOwners(gigOwner);
        assertEq(name, "NewGigOwner", "Gig owner name mismatch");
        assertEq(companyName, "NewCompany", "Company name mismatch");
        assertTrue(verified, "Gig owner should be verified");
        assertEq(stars, 5, "Stars not set correctly");
    }

    function testGigOwnerAccountUpdate() public {
    // Initially create the gig owner account.
    vm.prank(gigOwner);
    declan.createGigOwnerAccount("InitialGigOwner", gigOwner, "InitialCompany", true, 5);

    // "Update" the gig owner account by calling createGigOwnerAccount again.
    vm.prank(gigOwner);
    declan.createGigOwnerAccount("UpdatedGigOwner", gigOwner, "UpdatedCompany", false, 4);

    // Check if the gig owner account was updated successfully.
    (string memory name, , string memory companyName, bool verified, uint32 stars) = declan.gigOwners(gigOwner);
    assertEq(name, "UpdatedGigOwner", "Gig owner name mismatch after update");
    assertEq(companyName, "UpdatedCompany", "Company name mismatch after update");
    assertFalse(verified, "Gig owner should not be verified after update");
    assertEq(stars, 4, "Stars not set correctly after update");
}

    // Test that extending deadline on a completed gig reverts.
    function testExtendDeadlineFailsOnCompletedGig() public {
        uint256 budget = 1 ether;
        uint256 timeline = 7 days;
        
        vm.prank(gigOwner);
        uint256 gigId = declan.createGig("owner@example.com", "Test Gig", "Test description", timeline, budget);
        
        // Place and accept bid to get into WIP.
        vm.prank(verifiedFreelancer);
        declan.placeBid(gigId, budget);
        
        vm.prank(gigOwner);
        declan.acceptBid{value: budget}(gigId, 0);

        // Mark gig as completed.
        vm.prank(verifiedFreelancer);
        declan.completeGig(gigId);

        // Attempt to extend deadline should revert.
        vm.prank(gigOwner);
        vm.expectRevert("Gig is completed");
        declan.extendDeadline(gigId, 1 days);
    }

    // Test that confirming a gig that is not completed reverts.
    function testConfirmGigFailsIfNotCompleted() public {
        uint256 budget = 1 ether;
        uint256 timeline = 7 days;

        vm.prank(gigOwner);
        uint256 gigId = declan.createGig("owner@example.com", "Test Gig", "Test description", timeline, budget);
        
        // Gig remains in Open status (or becomes BidPlaced after placing a bid).
        vm.prank(verifiedFreelancer);
        declan.placeBid(gigId, budget);

        // Attempting to confirm before marking as Completed should revert.
        vm.prank(gigOwner);
        vm.expectRevert("Gig is not completed");
        declan.confirmGig(gigId);
    }


    // Test that withdrawFees reverts when no fees have been collected.
    function testWithdrawFeesRevertsWhenNoFees() public {
        // Make sure collectedFees is zero.
        uint256 fees = declan.collectedFees();
        assertEq(fees, 0, "Fees should initially be zero");

        vm.prank(contractOwner);
        vm.expectRevert("No fees to withdraw");
        declan.withdrawFees();
    }

    // Test the verifyFreelancer function branch when freelancer is already verified.
    function testVerifyFreelancerAlreadyVerified() public {
        // Freelancer is already verified in setUp.
        ( , , , bool initialVerified, , , , ) = declan.freelancers(verifiedFreelancer);
        assertTrue(initialVerified, "Freelancer should be verified initially");

        // Call verifyFreelancer again; since the condition is inside an if(!verified)
        // the state should remain unchanged.
        vm.prank(gigOwner);
        declan.verifyFreelancer(verifiedFreelancer, 5);

        ( , , , bool verifiedAfter, uint32 starsAfter, , , ) = declan.freelancers(verifiedFreelancer);
        assertTrue(verifiedAfter, "Freelancer should remain verified");
        // Assuming the stars update only happens if not already verified.
        // Adjust this assertion if your intended behavior is different.
        assertEq(starsAfter, 4, "Stars should remain unchanged if freelancer is already verified");
    }
    
    // Optionally, test reportGig when warningCount is less than 3 to see that no transfer happens.
    function testReportGigNoTransferWhenWarningCountLessThanThree() public {
        uint256 budget = 1 ether;
        uint256 timeline = 7 days;
    
        vm.prank(gigOwner);
        uint256 gigId = declan.createGig("owner@example.com", "Test Gig", "Test description", timeline, budget);
        
        // Place and accept bid.
        vm.prank(verifiedFreelancer);
        declan.placeBid(gigId, budget);
        vm.prank(gigOwner);
        declan.acceptBid{value: budget}(gigId, 0);

        // Do not extend deadline to increment warningCount to 3.
        // Call reportGig without meeting the transfer conditions.
        vm.prank(gigOwner);
        declan.reportGig(gigId);

        // Check that gig status has updated to Reported even though no transfer took place.
        ( , , , , , , , , , , Declan.GigStatus status, , , ) = declan.gigs(gigId);
        assertEq(uint256(status), uint256(Declan.GigStatus.Reported), "Gig status should be Reported");
    }

    // Add a receive function to enable the test contract to accept ETH transfers.
    receive() external payable {}
}
