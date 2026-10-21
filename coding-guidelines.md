12. Coding Guidelines

In order to code UseBy for iOS devices, Swift will be used to code the application. This includes both SwiftUI and SwiftData.
Here are the links for the coding guidelines that will be used by the team:
The official Swift coding guidelines:
https://www.swift.org/documentation/api-design-guidelines/
Other design guidelines: 
https://github.com/kodecocodes/swift-style-guide

The reason why these guidelines were chosen was because of how easy it is for others to understand our code. The official Swift coding guidelines are the community standard and match the conventions of Apple’s own frameworks, so our code reads consistently alongside SwiftUI and SwiftData. This makes it so much easier for others who want to understand and contribute to the code. They will be able to spend less time trying to understand our codebase and spend more time focusing on actually adding features.
As for the other guidelines, it is there to really solidify good coding practices. The official Swift guidelines are really good, but it is missing a lot of information on formatting and structuring. This includes things like indentation, line length etc. The Github guidelines are there to fill any gaps in guidelines that the official site is missing.
Overall, they are both widely used, well documented, and well supported by automated tooling. This makes it easy for new team members to learn and enforce. 

We'll go in order of Tool/Purpose for the Md File.

Tool: SwiftLint 
Purpose: Automatically flags style violations. Configured through a shared .swiftlint.yml in the repo. Runs locally as an Xcode build phase.

Tool 2: SwiftFormat 
Purpose: Auto-formats code (indentation, spacing, trailing commas) so style debates don’t come up in reviews. Run via a pre-commit hook. 

Tool 3: GitHub Actions CI 
Purpose: Runs SwiftLint and the full test suite on every PR. A PR cannot merge if lint errors or failing tests are present. 


Tool 4: Code review checklist 
Purpose: Manual confirmation that there is no style errors such as naming, documentation comments, no force unwraps or unhandled errors, and no leftover debug code that the previous checks didn’t catch.

Tool 5: Xcode “Treat Warnings as Errors” 
Purpose: Prevents compiler warnings from accumulating in release builds. Allows for the application to run easier on devices

////// Tool/Purpose Finished //////////

1. GitHub Maintenance and Workflow

We need to create good practices for Github control before starting the coding of our application. This will ensure that people are able to commit to the right 

2. Branching
One branch per person, with the naming practice of firstname/dev (for example, alex/dev). This will operate as that person’s personal workspace.

No direct pushing into main allowed. Merging requires a passing check and at least one teammate’s approval.

Members are expected to sync their personal branches with main at least once a week so that they are always working on the most up to date code.

Commit and Pushing in accordance with others

Members should push their code to their individual branch at least twice a week (ideally after every working session). This helps to save hard work and help with any surprise merge conflicts.

Commit messages should have either a short summary line (for example, “Add barcode scanner view”), or reference the issue (for example, “Fix expiry color bug”).
Never commit secrets, build artifacts, or personal Xcode settings.


3. Pull Requests

Each member opens a PR from their branch into main by Sunday evening. This gives the team members a standardized deadline to push code, allowing the group to evaluate progress on the Monday and Tuesday meetings.

PRs are reviewed within 48 hours. Each PR needs one approval from a teammate who did not write it. The team will meet once a week to review open PRs, resolve conflicts, and merge approved work (probably the Monday meeting).

Each PR is required to have:
Links to the relevant issue(s)
A short description of what changed and how to test it
Screenshots or screen recordings for UI changes
Passing SwiftLint and tests
Authors resolve review comments themselves; reviewers re-approve once changes are made.
