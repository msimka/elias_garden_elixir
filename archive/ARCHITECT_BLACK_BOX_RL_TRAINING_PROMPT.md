# Architect Consultation: Black Box RL as Sole Training Paradigm for ELIAS

## 🎯 **Training Philosophy Revolution**

### **Single Training Approach: Black Box Reinforcement Learning**
**User Decision**: "This is the only type of training we need to do. We can do everything like RL because I don't care how it does it, I just care that it accomplishes the goal."

**Key Insight**: No supervised fine-tuning needed. Pure goal-oriented optimization with constraints.

### **Training Paradigm**
```
Goal: "Send email to address@example.com"
Constraints: ["use Elixir", "put in /apps/elias_server/lib/email/", "use Org mode format"]
Test: Email actually sent + all asserts pass
Optimization: Code golf - find most efficient solution
Language: System chooses (unless constrained)
```

**Philosophy**: "I'm not going to have complex stuff that it needs to follow. I don't care how it does it, I just care that it accomplishes the goal."

## 🏗️ **Component Composition Training**

### **Progressive Component Building**
```
Stage 1: Component A → RL optimized
Stage 2: Component B → RL optimized  
Stage 3: Component C (integrates A + B) → RL learns optimal integration
```

**Natural Learning**: Constraints like "use Elixir" or "use Org mode" naturally teach patterns through RL exploration rather than supervised examples.

## 🤖 **Hardware Context: 32GB Dual RTX 5060 Ti**

### **Current Setup**
- **Existing**: RTX 5060 Ti (16GB VRAM)
- **Adding**: Second RTX 5060 Ti (16GB VRAM)
- **Total**: 32GB VRAM available for training
- **Previous Analysis**: Need 50-60GB for full training, 20-30GB for LoRA

### **Black Box RL Memory Requirements**
**Question for Architect**: How much VRAM does black box RL training require?
- Policy network training
- Value network training  
- Environment simulation (code execution sandbox)
- Component composition experiments

## 🎯 **Specific Implementation Questions**

### **1. RL Algorithm Selection**
**For Code Generation Goal Achievement**:
- **PPO** (Proximal Policy Optimization) for stable training?
- **DPO** (Direct Preference Optimization) for goal alignment?
- **Custom RL** algorithm optimized for code golf objectives?
- **Multi-objective optimization** (correctness + efficiency + constraints)?

### **2. Reward Function Design**
```elixir
# How to structure reward calculation?
defmodule BlackBoxReward do
  def calculate_reward(solution, goal_spec) do
    # Primary: Goal achievement (0 or 100 points)
    goal_achieved = test_goal_completion(solution, goal_spec.test)
    
    # Secondary: Assert compliance  
    assert_score = calculate_assert_compliance(solution, goal_spec.asserts)
    
    # Optimization: Code golf metrics
    efficiency_score = calculate_code_golf_score(solution)
    
    # Constraint compliance
    constraint_score = validate_constraints(solution, goal_spec.constraints)
    
    # Total reward calculation?
    combine_scores(goal_achieved, assert_score, efficiency_score, constraint_score)
  end
end
```

### **3. Training Environment Architecture**
**Execution Sandbox Requirements**:
- **Language Support**: Multi-language execution (Elixir, Python, Rust, etc.)
- **Safety**: Isolated execution environment  
- **Testing**: Automated goal verification
- **Performance Measurement**: Code golf optimization metrics
- **Integration Testing**: Component composition validation

### **4. Component Composition Strategy**
**Progressive Integration Training**:
```
Component A (email sender) → Optimized
Component B (data processor) → Optimized
Component C = f(A, B) → RL learns optimal integration patterns
```

**Questions**:
- How to train composition without losing individual component optimization?
- Multi-objective rewards for integration + individual performance?
- Memory requirements for training integrated components?

### **5. Manager Specialization via RL**
**Each Manager's Black Box RL Focus**:

#### **UFM**: Federation orchestration goals
- Goal: "Coordinate 7 managers for task X"
- Constraints: ["maintain <100ms latency", "use GenServer patterns"]
- Optimization: Minimal coordination overhead

#### **UCM**: Content processing goals  
- Goal: "Process file from format A to format B"
- Constraints: ["maintain quality", "use streaming"]
- Optimization: Fastest processing with quality preservation

#### **ULM**: Learning optimization goals (3 domains)
- **Core System**: "Improve Tank Building methodology compliance by 5%"
- **External Apps**: "Optimize estate sales feature for user engagement"  
- **Personal Learning**: "Optimize Japanese learning velocity for user"

#### **UDM**: Deployment goals (2 domains)
- **Internal**: "Deploy core system update with zero downtime"
- **External**: "Deploy estate sales feature with <1% error rate"

### **6. Training Distribution Across 7 Managers**
**58h/Week RL Training**:
- How to distribute black box RL across all managers?
- Sequential training (one manager at a time) vs parallel?
- Component composition training allocation?

### **7. Memory Optimization for 32GB**
**Fitting Black Box RL in Dual RTX 5060 Ti**:
- Gradient checkpointing for RL algorithms?
- Sequential component training to stay within memory?
- Model sharding across dual GPUs?

## 🔬 **Technical Implementation Questions**

### **RL Environment Integration**
```python
# Black box RL training environment
class EliasRLEnvironment:
    def step(self, action):  # action = generated code
        # Execute code in sandbox
        # Run goal test + asserts
        # Calculate reward
        # Return (observation, reward, done, info)
```

### **Goal Specification Language**
```elixir
# Standardized goal format for all managers
%GoalSpec{
  description: "Send email to specific address",
  test_function: &email_test/1,
  constraints: ["use Elixir", "file: /apps/email/sender.ex"],
  asserts: [security_check, performance_check],
  optimization_target: :code_golf,
  success_threshold: 100, # Must achieve goal
  efficiency_weight: 0.3  # Code golf importance
}
```

---

**Architect**: Given our decision to use **black box RL as the sole training paradigm**:

1. **What RL algorithm** is optimal for code generation goal achievement?
2. **How much VRAM** does black box RL training require vs supervised training?
3. **Can we fit** effective RL training in 32GB VRAM (dual RTX 5060 Ti)?
4. **How to structure** reward functions for code golf optimization?
5. **What's the optimal** training environment for multi-language code generation?
6. **How to implement** component composition training via RL?
7. **Training distribution** strategy for 58h/week across 7 managers with RL?

**Core Question**: Can black box RL replace all supervised fine-tuning for our use case, and how to implement optimally on our hardware?