// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/// =============================================================
/// 🏘️ ResidenceAssociationERC1155
/// ERC1155-based registry for Tenants → Facilities
/// =============================================================
contract ResidenceAssociationERC1155 is ERC1155, Ownable, ReentrancyGuard {
    // =============================================================
    // 🧩 Data Structures
    // =============================================================

    enum FacilityType {
        SwimmingPool,
        Gym,
        Billiards,
        Golf,
        Tennis
    }

    struct Tenant {
        string name;
        string apartmentNumber;
        bool active;
        string metadataURI;
    }

    struct FacilityAccess {
        bool active;
        uint256 startTime;
        uint256 endTime;
        uint256 months;
    }

    // =============================================================
    // 🧭 Storage
    // =============================================================

    uint256 public nextTenantId = 1;

    mapping(uint256 => Tenant) public tenants; // tenantId → Tenant
    mapping(uint256 => mapping(FacilityType => FacilityAccess)) public tenantFacilities; // tenantId → FacilityType → FacilityAccess

    address[] public tenantAddresses; // for listing all tenants
    mapping(address => uint256) public tenantIds; // tenant address → tenantId

    // =============================================================
    // 🪩 Events
    // =============================================================

    event TenantRegistered(
        uint256 indexed tenantId,
        address indexed tenantAddress,
        string name,
        string apartmentNumber
    );

    event TenantUpdated(
        uint256 indexed tenantId,
        string name,
        string apartmentNumber,
        bool active
    );

    event FacilityGranted(
        uint256 indexed tenantId,
        FacilityType facility,
        uint256 months,
        uint256 endTime
    );

    event FacilityRevoked(
        uint256 indexed tenantId,
        FacilityType facility
    );

    // =============================================================
    // ⚙️ Constructor
    // =============================================================

    constructor() ERC1155("") Ownable(msg.sender) {}

    // =============================================================
    // 🏠 Tenant Management
    // =============================================================

    /// @notice Register a new tenant and mint them a membership token
    function registerTenant(
        address tenantAddress,
        string memory name,
        string memory apartmentNumber,
        string memory metadataURI
    ) external onlyOwner returns (uint256 tenantId) {
        require(tenantAddress != address(0), "Invalid tenant address");

        tenantId = nextTenantId++;
        tenants[tenantId] = Tenant({
            name: name,
            apartmentNumber: apartmentNumber,
            active: true,
            metadataURI: metadataURI
        });

        tenantAddresses.push(tenantAddress);
        tenantIds[tenantAddress] = tenantId;

        _mint(tenantAddress, tenantId, 1, ""); // 1 token per tenant

        emit TenantRegistered(tenantId, tenantAddress, name, apartmentNumber);
    }

    /// @notice Update tenant info
    function updateTenant(
        uint256 tenantId,
        string memory name,
        string memory apartmentNumber,
        bool active,
        string memory newURI
    ) external onlyOwner {
        Tenant storage t = tenants[tenantId];
        require(t.active, "Tenant inactive");

        t.name = name;
        t.apartmentNumber = apartmentNumber;
        t.active = active;
        if (bytes(newURI).length > 0) t.metadataURI = newURI;

        emit TenantUpdated(tenantId, name, apartmentNumber, active);
    }

    // =============================================================
    // 🎾 Facility Management
    // =============================================================

    /// @notice Grant access to a facility for a tenant
    function grantFacility(
        uint256 tenantId,
        FacilityType facility,
        uint256 months
    ) external payable onlyOwner nonReentrant {
        Tenant storage t = tenants[tenantId];
        require(t.active, "Tenant inactive");
        require(months > 0, "Invalid period");

        uint256 start = block.timestamp;
        uint256 end = start + (months * 30 days);

        tenantFacilities[tenantId][facility] = FacilityAccess({
            active: true,
            startTime: start,
            endTime: end,
            months: months
        });

        emit FacilityGranted(tenantId, facility, months, end);
    }

    /// @notice Revoke facility access manually
    function revokeFacility(uint256 tenantId, FacilityType facility) external onlyOwner {
        FacilityAccess storage access = tenantFacilities[tenantId][facility];
        require(access.active, "Facility not active");

        access.active = false;
        emit FacilityRevoked(tenantId, facility);
    }

    /// @notice Check if tenant currently has facility access
    function checkFacilityStatus(uint256 tenantId, FacilityType facility)
        external
        view
        returns (bool active, uint256 endTime)
    {
        FacilityAccess storage access = tenantFacilities[tenantId][facility];
        if (access.active && block.timestamp <= access.endTime) {
            return (true, access.endTime);
        } else {
            return (false, access.endTime);
        }
    }

    // =============================================================
    // 🔍 View Functions
    // =============================================================

    function getTenant(uint256 tenantId)
        external
        view
        returns (
            string memory name,
            string memory apartmentNumber,
            bool active,
            string memory metadataURI
        )
    {
        Tenant storage t = tenants[tenantId];
        return (t.name, t.apartmentNumber, t.active, t.metadataURI);
    }

    function getAllTenants() external view returns (address[] memory) {
        return tenantAddresses;
    }

    /// @notice ERC1155 metadata URI override (per tenant)
    function uri(uint256 tenantId) public view override returns (string memory) {
        return tenants[tenantId].metadataURI;
    }

    // =============================================================
    // 🚫 Fallback
    // =============================================================
    receive() external payable {
        revert("Direct payments not allowed");
    }
}
