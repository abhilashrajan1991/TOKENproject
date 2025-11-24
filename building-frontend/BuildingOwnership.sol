// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract BuildingOwnership is ERC1155, Ownable, ReentrancyGuard {
    struct Room {
        string name;
        uint256 pricePerShare;
        uint256 totalShares;
        bool forLease;
    }

    struct Lease {
        uint256 shares;
        uint256 endTime;
        uint256 totalRent;
    }

    uint256 public constant TOTAL_ROOMS = 8;

    mapping(uint256 => Room) public rooms;
    mapping(uint256 => mapping(address => Lease)) public leases;
    mapping(uint256 => address[]) private roomTenants;

    event RoomCreated(uint256 indexed roomId, string name, uint256 totalShares, uint256 pricePerShare);
    event RoomLeased(uint256 indexed roomId, address indexed tenant, uint256 shares, uint256 months, uint256 totalRent);
    event LeaseReclaimed(uint256 indexed roomId, address indexed tenant, uint256 shares);
    event RoomLeaseStatusUpdated(uint256 indexed roomId, bool forLease, uint256 newPricePerShare);

    constructor() ERC1155("") Ownable(msg.sender) {
        _createRoom(1, "Apartment 1", 100, 0.01 ether);
        _createRoom(2, "Apartment 2", 100, 0.01 ether);
        _createRoom(3, "Apartment 3", 100, 0.01 ether);
        _createRoom(4, "Apartment 4", 100, 0.01 ether);
        _createRoom(5, "Apartment 5", 100, 0.01 ether);
        _createRoom(6, "Shop 6", 100, 0.02 ether);
        _createRoom(7, "Shop 7", 100, 0.02 ether);
        _createRoom(8, "Shop 8", 100, 0.02 ether);
    }

    function _createRoom(uint256 roomId, string memory name, uint256 totalShares, uint256 pricePerShare) internal {
        rooms[roomId] = Room(name, pricePerShare, totalShares, true);
        // Mint all shares to the contract itself
        _mint(address(this), roomId, totalShares, "");
        emit RoomCreated(roomId, name, totalShares, pricePerShare);
    }

    function leaseRoomShares(uint256 roomId, uint256 shares, uint256 months) external payable nonReentrant {
        Room storage room = rooms[roomId];
        require(room.forLease, "Room not for lease");
        require(balanceOf(address(this), roomId) >= shares, "Not enough shares in contract");

        uint256 totalRent = shares * room.pricePerShare * months;
        require(msg.value >= totalRent, "Insufficient payment");

        Lease storage lease = leases[roomId][msg.sender];
        lease.shares += shares;
        lease.endTime = block.timestamp + (months * 30 days);
        lease.totalRent += totalRent;

        roomTenants[roomId].push(msg.sender);

        // Transfer shares from contract to tenant
        _safeTransferFrom(address(this), msg.sender, roomId, shares, "");

        emit RoomLeased(roomId, msg.sender, shares, months, totalRent);
    }

    function reclaimExpiredLease(uint256 roomId, address tenant) external onlyOwner nonReentrant {
        Lease storage lease = leases[roomId][tenant];
        require(lease.endTime < block.timestamp, "Lease still active");
        uint256 shares = lease.shares;
        require(shares > 0, "No shares to reclaim");

        lease.shares = 0;
        lease.endTime = 0;
        lease.totalRent = 0;

        // Transfer shares back to the contract
        _safeTransferFrom(tenant, address(this), roomId, shares, "");
        emit LeaseReclaimed(roomId, tenant, shares);
    }

    function updateRoomLeaseStatus(uint256 roomId, bool _forLease, uint256 _pricePerShare) external onlyOwner {
        Room storage room = rooms[roomId];
        room.forLease = _forLease;
        room.pricePerShare = _pricePerShare;
        emit RoomLeaseStatusUpdated(roomId, _forLease, _pricePerShare);
    }

    function checkLeaseStatus(uint256 roomId, address tenant) external view returns (bool active, uint256 endTime, uint256 shares) {
        Lease memory lease = leases[roomId][tenant];
        return (lease.endTime >= block.timestamp, lease.endTime, lease.shares);
    }

    function getRoom(uint256 roomId) external view returns (string memory name, uint256 pricePerShare, uint256 totalShares, bool forLease) {
        Room memory room = rooms[roomId];
        return (room.name, room.pricePerShare, room.totalShares, room.forLease);
    }

    function getTenants(uint256 roomId) external view returns (address[] memory) {
        return roomTenants[roomId];
    }
}
