# Find-LoopedADGroups
I wrote a tool that comprehensively identifies and analyzes looped group membership within an Active Directory domain.  Features include:
- Avoids use of programmatic recursion and includes safeguards against infinite feedback loops.
- Supports all group types (Global, Domain Local, Universal).
- Identifies loops with numerous members (ex. A is a member of B, B is a member of C, C is a member of D, and D is a member of A).
- Identifies "loops within loops", wherein a single group may be a participant in multiple loops.
- Provides readable text output which describes how each loop is formed.

## Installation/Loading
```console
Import-Module .\Find-LoopedADGroups.ps1
```

## Usage
You need to have the ActiveDirectory PowerShell module installed/loaded (available in RSAT Tools).  Once that is available, run the function:
```console
Find-LoopedADGroups
```

The code outputs an object for each set of groups that are determined to be participating in one or more loops.  The object has several properties:
- LoopParticipants:  An array of the Distinguished Names of the groups participating in the loop(s).
- StartingGroup:  The group that was being analyzed when the loop was initially detected.
- LoopAnalysis:  A hashtable of name/value pairs that contains an analysis of each loop that was detected amongst the members in LoopParticipants.  The hashtable may contain multiple name/value pairs if the groups are looped multiple times within each other.

## Example
For this example I created some test groups in Active Directory (Group1 through Group9), and set up several loops:
- Group2 is a member of Group1
- Group3 is a member of Group2
- Group4 is a member of Group3
- Group1 and Group5 are members of Group4 (this technically creates two loops in Group1 through Group6)
- Group6 is a member of Group5
- Group1 is a member of Group6
- Group8 is a member of Group7
- Group9 is a member of Group8
- Group7 is a member of Group9

The code returns two objects because there are two sets of groups (Group1 through Group6 and Group7 through Group9) that have one or more loops between them.

![image](https://github.com/vwaniel/Find-LoopedADGroups/assets/62962179/b8c3a4c5-4b98-42e4-b7d2-738b97b8457d)

Examining the results for Group1 through Group6 more closely, we can see that there were two loops detected in LoopAnalysis (because Group1 AND Group5 are members of Group4).

![image](https://github.com/vwaniel/Find-LoopedADGroups/assets/62962179/34e14fe2-645b-4534-bf93-0efc0c5cc726)

Taking a closer look at the loop analysis results we can see that the code correct identified both loops along with an easy to follow explanation of why each loop exists.

![image](https://github.com/vwaniel/Find-LoopedADGroups/assets/62962179/db482105-a4eb-4c55-a26b-5198875dd83b)
