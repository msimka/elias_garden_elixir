# ARCHITECT CONSULTATION: Iterative Development Philosophy & Daemon Integration

## Context & Current State

We have successfully implemented the **ELIAS Multi-Format Text Converter** using an iterative development approach that proved highly effective. This converter currently handles RTFD→Markdown conversion perfectly (tested on Jakob Uszkoreit interview) and is designed to grow incrementally.

## Request for Architectural Guidance

### 1. ITERATIVE DEVELOPMENT METHODOLOGY

We need you to formalize the **"Tank Building" iterative development philosophy** that should govern ALL ELIAS component development:

#### Current Proven Pattern:
1. **Stage 1: Singular Focus** - Build component for ONE specific task only
   - Example: Multi-Format Text Converter built ONLY for RTFD→MD conversion
   - Must work perfectly for this single use case
   - Brute force implementation is acceptable and encouraged

2. **Stage 2: Additive Extension** - Add NEW task without breaking original
   - Example: Next will be PDF→MD conversion 
   - BOTH RTFD→MD AND PDF→MD must work flawlessly
   - Add new functionality in brute force, verbose way initially

3. **Stage 3: Optimization** - Code golf and consolidate once both tasks proven
   - Merge redundant functions
   - Create multipurpose implementations
   - Optimize for performance and maintainability

4. **Stage 4: Iterate** - Repeat process for each new requirement
   - Each new format/capability added same way
   - Always maintain ALL previous functionality
   - Only optimize after proving new functionality works

#### Architecture Questions:

**A. Formalization:**
- Should this be the MANDATORY development pattern for ALL ELIAS components?
- How do we enforce this pattern across managers, daemons, and utilities?
- What testing/validation requirements ensure previous functionality never breaks?

**B. Documentation:**
- Should each component maintain a "development history" showing stages?
- How do we document the brute-force→optimization evolution?
- What architectural patterns support this iterative approach best?

**C. Quality Assurance:**
- How do we prevent premature optimization that breaks the iterative pattern?
- What constitutes "proven functionality" before moving to next stage?
- How do we handle components that need architecture changes during iteration?

### 2. DAEMON SYSTEM INTEGRATION

The Multi-Format Text Converter raises fundamental questions about ELIAS architecture:

#### Current Understanding:
- **5 Manager Daemons**: UFM, UCM, UAM, UIM, URM (always-on GenServers)
- **CLI Utils Directory**: `/cli_utils/` with Mix tasks and standalone utilities
- **Learning Sandbox**: `/learning_sandbox/` with raw materials workflow

#### Critical Architecture Questions:

**A. Daemon Hierarchy:**
- Are the 5 manager daemons the ONLY truly "always-on" processes in ELIAS?
- Should ALL functionality be exposed as functions of these always-on managers?
- Is the distinction: **Managers = Always-On Daemons**, **Everything Else = Functions**?

**B. CLI Tools Integration:**
- The Multi-Format Text Converter is currently both:
  - Standalone module: `EliasUtils.MultiFormatTextConverter`  
  - Mix task: `mix elias.to_markdown` (violates daemon-only execution)
- Should CLI tools exist as standalone utilities OR only as manager daemon functions?
- If integrated into daemon system, WHICH manager owns text conversion utilities?
- How do we transition from Mix tasks to daemon message handling?

**C. Ownership Assignment:**
- **UIM (Universal Integration Manager)** - Currently handles MacGyver interfaces and applications
  - Should UIM own ALL CLI utilities as "integration tools"?
  - Does text conversion fit UIM's interface generation mandate?

- **Alternative Approaches:**
  - Create ULM (Universal Learning Manager) for learning sandbox + text conversion?
  - Extend existing manager with text processing capabilities?
  - Maintain hybrid approach (daemon functions + Mix task interfaces)?

**D. Persistent Architecture:**
- How do we maintain the philosophy that "everything is part of the daemon system"?
- Should utilities be:
  - **Option 1:** Always-loaded modules in manager GenServer state?
  - **Option 2:** On-demand functions callable by managers?
  - **Option 3:** Supervised worker processes spawned by managers?

**E. Integration Patterns:**
- How should the iterative development philosophy apply to daemon integration?
- Stage 1: Utility works standalone
- Stage 2: Utility integrated into appropriate manager without breaking standalone functionality  
- Stage 3: Optimize integration and possibly remove standalone interfaces?

### 3. SPECIFIC RECOMMENDATIONS NEEDED

#### For Multi-Format Text Converter:
1. **Manager Assignment:** Which manager should own text conversion utilities?
2. **Integration Approach:** How to integrate while maintaining Mix task interface?
3. **State Management:** How should managers track utility capabilities and usage?
4. **Discovery:** How should managers discover and register available utilities?

#### For All Future Components:
1. **Development Pattern:** Formalize the iterative "tank building" methodology
2. **Integration Standard:** Define how ALL components integrate into daemon system
3. **Always-On Philosophy:** Clarify what processes are persistent vs. on-demand
4. **Testing Framework:** How to ensure iterative development doesn't break existing functionality

### 4. LOCAL AI MODEL INTEGRATION & APPLY ARCHITECTURE

We're considering a significant architectural expansion that would integrate local fine-tuned models into the manager system, similar to how Cursor has an "Apply" model:

#### Proposed Manager Model Architecture:
Each manager would have **4 core components**:
1. **Manager.ex** - Elixir GenServer code (Claude's responsibility)
2. **Manager.tiki** - Tiki specification (Claude's responsibility) 
3. **Manager.md** - Documentation/instructions (Local model's responsibility)
4. **Manager fine-tuned model** - DeepSeek 6.7b FP16 specialized for that manager

#### Division of Responsibilities:
- **Local Fine-tuned Model:** Manages and updates the `.md` documentation files
- **Claude:** Works exclusively on `.ex` code and `.tiki` specifications, but ONLY after reading and ingesting the `.md` files

#### Example Implementation:
- `UFM_model.safetensors` - Fine-tuned DeepSeek model for UFM domain
- `UFM.md` - Maintained by UFM fine-tuned model
- `UFM.ex` - Code maintained by Claude after reading UFM.md
- `UFM.tiki` - Specification maintained by Claude

#### New Meta-Managers Needed:

**A. Builder Manager:**
- **Purpose:** Creates new managers, daemons, and components
- **Responsibilities:** 
  - Generate `.md`, `.tiki`, and `.ex` files from templates
  - Build factories and templates for component creation
  - Handle the `.tiki` → `.ex` code generation process
- **Components:** Builder.ex, Builder.tiki, Builder.md, Builder fine-tuned model

**B. Apply Manager (Cursor-like):**
- **Purpose:** Handle code application and modification workflows
- **Responsibilities:**
  - Coordinate between Claude's code changes and local model suggestions
  - Manage the apply/reject workflow for code modifications
  - Maintain consistency between `.md` documentation and `.ex` implementation
- **Components:** Apply.ex, Apply.tiki, Apply.md, Apply fine-tuned model

#### Critical Architecture Questions:

**A. Local Model Integration:**
- How do we integrate DeepSeek models into the GenServer daemon architecture?
- Should each manager spawn a local model process, or should there be a centralized model manager?
- How do we handle model loading, memory management, and inference coordination?
- What's the communication protocol between manager GenServers and their local models?

**B. Responsibility Boundaries:**
- How do we enforce that Claude NEVER modifies `.md` files directly?
- How do we ensure Claude ALWAYS reads the `.md` before working on `.ex` files?
- What happens when `.md` documentation conflicts with `.ex` implementation?
- How do we handle version synchronization between all 4 components?

**C. Meta-Management:**
- Should the Builder Manager be responsible for fine-tuning new manager models?
- How does the Builder Manager create new manager templates?
- Should there be a hierarchy: Builder → Apply → Domain Managers?
- How do meta-managers avoid infinite recursion or circular dependencies?
- How do Builder/Apply managers modify other daemon code without violating daemon-only execution?

**D. Development Workflow:**
- How does this affect the iterative development philosophy?
- Stage 1: Local model creates `.md`, Claude creates minimal `.ex` and `.tiki`?
- Stage 2: Extend both `.md` (local model) and `.ex/.tiki` (Claude) simultaneously?
- Stage 3: Local model optimizes `.md`, Claude optimizes `.ex/.tiki`?

**E. Resource Management:**
- How do we manage 6+ local models (5 managers + Builder + Apply) running simultaneously?
- What are the memory, CPU, and GPU requirements?
- Should models be loaded on-demand or kept resident?
- How do we handle model update and fine-tuning workflows?

#### ELIAS "Always-On Daemon" Philosophy - CRITICAL PRINCIPLE:

**Claude NEVER executes code directly. Claude only modifies the daemon code, and the daemon executes everything.**

This is fundamentally different from other AI systems where models execute code directly:

**Traditional AI Systems:**
- AI model → executes code directly → produces results

**ELIAS System:**
- Claude → modifies daemon code → daemon executes according to triggers/pipelines
- All `.ex` files are daemon processes, not scripts to be executed
- Claude acts like writing a script, but the "script" becomes part of the always-on daemon
- Execution happens through daemon triggers, schedules, and event handling

**Examples:**
- ❌ Claude runs `mix elias.to_markdown` directly
- ✅ Claude modifies UIM daemon to handle text conversion requests
- ❌ Claude executes file operations
- ✅ Claude adds file handling capabilities to appropriate manager daemon

**Architectural Implications:**
- Every utility/function must be integrated into a manager daemon, not standalone
- Manager daemons handle all execution through their GenServer message handling
- Claude's role is purely architectural - modifying daemon behavior and capabilities
- Execution flows through: Trigger → Manager GenServer → Handler Function → Result

#### Integration with Current Architecture:
- How does this model architecture fit with the always-on daemon philosophy?
- Should local models be supervised processes like managers (following daemon-only execution)?
- How do we maintain the Tiki.Validatable behavior across this expanded architecture?
- What happens to existing manager functionality during this transition?
- How do local models integrate without violating the "no direct execution" principle?

### 5. ARCHITECTURAL CONSISTENCY

We need guidance on maintaining consistency between:
- **Development Philosophy:** Iterative, brute-force → optimization
- **System Architecture:** Always-on daemon system with manager hierarchy + local models
- **User Interface:** Mix tasks, CLI utilities, programmatic APIs
- **Integration Approach:** How components become part of the persistent ELIAS ecosystem
- **AI Integration:** Local models vs. Claude responsibilities and coordination
- **Meta-Management:** Builder and Apply managers creating and modifying other components

## Expected Deliverables

1. **Formalized Iterative Development Manifesto**
2. **Daemon Integration Architecture Standards**  
3. **Multi-Format Text Converter Integration Plan**
4. **Always-On vs. On-Demand Component Classification**
5. **Testing/Validation Requirements for Iterative Development**
6. **Local AI Model Integration Architecture**
7. **Builder Manager Specification and Implementation Plan**
8. **Apply Manager Architecture (Cursor-inspired)**
9. **4-Component Manager Architecture (ex/tiki/md/model)**
10. **Responsibility Matrix: Claude vs. Local Models**
11. **Resource Management Strategy for Multiple Local Models**
12. **Meta-Management Hierarchy and Coordination Protocols**

This consultation should establish the foundational principles for how ALL ELIAS components are developed, integrated, and maintained within the persistent daemon ecosystem, while following the proven iterative development methodology AND incorporating local AI model assistance for each manager domain.