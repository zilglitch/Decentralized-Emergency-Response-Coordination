// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title Decentralized Emergency Response Coordination
 * @dev Smart contract for coordinating emergency responses in a decentralized manner
 * @author Emergency Response Team
 */
contract DecentralizedEmergencyResponseCoordination {
    
    // Emergency severity levels
    enum Severity { LOW, MEDIUM, HIGH, CRITICAL }
    
    // Emergency status types
    enum Status { REPORTED, ACKNOWLEDGED, IN_PROGRESS, RESOLVED, CANCELLED }
    
    // Structure to represent an emergency report
    struct Emergency {
        uint256 id;
        address reporter;
        string location;
        string description;
        Severity severity;
        Status status;
        uint256 timestamp;
        address assignedResponder;
        uint256 responseTime;
        bool verified;
    }
    
    // Structure to represent a responder
    struct Responder {
        address responderAddress;
        string name;
        string specialty; // e.g., "Medical", "Fire", "Police", "Rescue"
        bool isActive;
        uint256 totalResponses;
        uint256 averageResponseTime;
        bool isVerified;
    }
    
    // State variables
    address public admin;
    uint256 public emergencyCounter;
    uint256 public constant RESPONSE_TIME_LIMIT = 30 minutes;
    
    // Mappings
    mapping(uint256 => Emergency) public emergencies;
    mapping(address => Responder) public responders;
    mapping(address => bool) public authorizedReporters;
    mapping(uint256 => address[]) public emergencyResponders; // Multiple responders per emergency
    
    // Events
    event EmergencyReported(
        uint256 indexed emergencyId,
        address indexed reporter,
        string location,
        Severity severity,
        uint256 timestamp
    );
    
    event ResponderAssigned(
        uint256 indexed emergencyId,
        address indexed responder,
        uint256 timestamp
    );
    
    event EmergencyStatusUpdated(
        uint256 indexed emergencyId,
        Status oldStatus,
        Status newStatus,
        address updatedBy
    );
    
    event ResponderRegistered(
        address indexed responder,
        string name,
        string specialty
    );
    
    // Modifiers
    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can perform this action");
        _;
    }
    
    modifier onlyActiveResponder() {
        require(responders[msg.sender].isActive, "Only active responders can perform this action");
        _;
    }
    
    modifier onlyAuthorizedReporter() {
        require(authorizedReporters[msg.sender] || msg.sender == admin, "Not authorized to report emergencies");
        _;
    }
    
    modifier emergencyExists(uint256 _emergencyId) {
        require(_emergencyId > 0 && _emergencyId <= emergencyCounter, "Emergency does not exist");
        _;
    }
    
    // Constructor
    constructor() {
        admin = msg.sender;
        emergencyCounter = 0;
        authorizedReporters[admin] = true;
    }
    
    /**
     * @dev Core Function 1: Report Emergency
     * @param _location Location of the emergency
     * @param _description Description of the emergency
     * @param _severity Severity level of the emergency
     */
    function reportEmergency(
        string memory _location,
        string memory _description,
        Severity _severity
    ) external onlyAuthorizedReporter returns (uint256) {
        require(bytes(_location).length > 0, "Location cannot be empty");
        require(bytes(_description).length > 0, "Description cannot be empty");
        
        emergencyCounter++;
        
        emergencies[emergencyCounter] = Emergency({
            id: emergencyCounter,
            reporter: msg.sender,
            location: _location,
            description: _description,
            severity: _severity,
            status: Status.REPORTED,
            timestamp: block.timestamp,
            assignedResponder: address(0),
            responseTime: 0,
            verified: false
        });
        
        emit EmergencyReported(
            emergencyCounter,
            msg.sender,
            _location,
            _severity,
            block.timestamp
        );
        
        return emergencyCounter;
    }
    
    /**
     * @dev Core Function 2: Assign Responder to Emergency
     * @param _emergencyId ID of the emergency
     * @param _responder Address of the responder to assign
     */
    function assignResponder(
        uint256 _emergencyId,
        address _responder
    ) external onlyAdmin emergencyExists(_emergencyId) {
        require(responders[_responder].isActive, "Responder is not active");
        require(
            emergencies[_emergencyId].status == Status.REPORTED || 
            emergencies[_emergencyId].status == Status.ACKNOWLEDGED,
            "Emergency cannot be assigned at current status"
        );
        
        Emergency storage emergency = emergencies[_emergencyId];
        emergency.assignedResponder = _responder;
        emergency.status = Status.ACKNOWLEDGED;
        emergency.responseTime = block.timestamp;
        
        // Add responder to the emergency responders list
        emergencyResponders[_emergencyId].push(_responder);
        
        emit ResponderAssigned(_emergencyId, _responder, block.timestamp);
        emit EmergencyStatusUpdated(_emergencyId, Status.REPORTED, Status.ACKNOWLEDGED, msg.sender);
    }
    
    /**
     * @dev Core Function 3: Update Emergency Status
     * @param _emergencyId ID of the emergency
     * @param _newStatus New status to set
     */
    function updateEmergencyStatus(
        uint256 _emergencyId,
        Status _newStatus
    ) external emergencyExists(_emergencyId) {
        Emergency storage emergency = emergencies[_emergencyId];
        
        // Check permissions
        require(
            msg.sender == admin || 
            msg.sender == emergency.assignedResponder || 
            msg.sender == emergency.reporter,
            "Not authorized to update this emergency"
        );
        
        Status oldStatus = emergency.status;
        emergency.status = _newStatus;
        
        // Update responder statistics when emergency is resolved
        if (_newStatus == Status.RESOLVED && emergency.assignedResponder != address(0)) {
            Responder storage responder = responders[emergency.assignedResponder];
            responder.totalResponses++;
            
            // Calculate new average response time
            uint256 currentResponseTime = block.timestamp - emergency.responseTime;
            if (responder.totalResponses == 1) {
                responder.averageResponseTime = currentResponseTime;
            } else {
                responder.averageResponseTime = 
                    (responder.averageResponseTime * (responder.totalResponses - 1) + currentResponseTime) 
                    / responder.totalResponses;
            }
        }
        
        emit EmergencyStatusUpdated(_emergencyId, oldStatus, _newStatus, msg.sender);
    }
    
    // Additional utility functions
    
    /**
     * @dev Register a new responder
     * @param _responder Address of the responder
     * @param _name Name of the responder
     * @param _specialty Specialty of the responder
     */
    function registerResponder(
        address _responder,
        string memory _name,
        string memory _specialty
    ) external onlyAdmin {
        require(_responder != address(0), "Invalid responder address");
        require(bytes(_name).length > 0, "Name cannot be empty");
        require(bytes(_specialty).length > 0, "Specialty cannot be empty");
        
        responders[_responder] = Responder({
            responderAddress: _responder,
            name: _name,
            specialty: _specialty,
            isActive: true,
            totalResponses: 0,
            averageResponseTime: 0,
            isVerified: true
        });
        
        emit ResponderRegistered(_responder, _name, _specialty);
    }
    
    /**
     * @dev Authorize a reporter
     * @param _reporter Address to authorize
     */
    function authorizeReporter(address _reporter) external onlyAdmin {
        require(_reporter != address(0), "Invalid reporter address");
        authorizedReporters[_reporter] = true;
    }
    
    /**
     * @dev Deactivate a responder
     * @param _responder Address of the responder to deactivate
     */
    function deactivateResponder(address _responder) external onlyAdmin {
        responders[_responder].isActive = false;
    }
    
    /**
     * @dev Get emergency details
     * @param _emergencyId ID of the emergency
     */
    function getEmergency(uint256 _emergencyId) 
        external 
        view 
        emergencyExists(_emergencyId) 
        returns (Emergency memory) {
        return emergencies[_emergencyId];
    }
    
    /**
     * @dev Get responder details
     * @param _responder Address of the responder
     */
    function getResponder(address _responder) 
        external 
        view 
        returns (Responder memory) {
        return responders[_responder];
    }
    
    /**
     * @dev Get all responders assigned to an emergency
     * @param _emergencyId ID of the emergency
     */
    function getEmergencyResponders(uint256 _emergencyId) 
        external 
        view 
        emergencyExists(_emergencyId) 
        returns (address[] memory) {
        return emergencyResponders[_emergencyId];
    }
    
    /**
     * @dev Check if response time limit has been exceeded
     * @param _emergencyId ID of the emergency
     */
    function isResponseOverdue(uint256 _emergencyId) 
        external 
        view 
        emergencyExists(_emergencyId) 
        returns (bool) {
        Emergency memory emergency = emergencies[_emergencyId];
        
        if (emergency.status == Status.RESOLVED || emergency.status == Status.CANCELLED) {
            return false;
        }
        
        return (block.timestamp - emergency.timestamp) > RESPONSE_TIME_LIMIT;
    }
    
    /**
     * @dev Get total number of emergencies
     */
    function getTotalEmergencies() external view returns (uint256) {
        return emergencyCounter;
    }
} 




Contract address : 0xB7f0fA38430d1d5aE35098C0A96F0530eD0296FF




