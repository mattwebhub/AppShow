# Store dependency evidence inventory

Snapshot: 2026-09-09. Source: the committed `Package.resolved` and local resolved checkouts. This records evidence to review; it does not grant store distribution approval or establish that every resolved package is linked into the store binary.

| Resolved package | Version | Revision | Root license evidence |
| --- | --- | --- | --- |
| menubarextraaccess | 1.2.2 | 707dff6f55217b3ef5b6be84ced3e83511d4df5c | MIT |
| rnnoise-spm | 1.1.0 | 9bb6d4c4971a8594f9306cdb1acb6b4013b6ef05 | License evidence missing from root; inspect binary/source distribution |
| sparkle | 2.9.0 | 21d8df80440b1ca3b65fa82e40782f1e5a9e6ba2 | MIT |
| swift-argument-parser | 1.7.0 | c5d11a805e765f52ba34ec7284bd4fcd6ba68615 | Apache-2.0 |
| swift-asn1 | 1.5.1 | 810496cf121e525d660cd0ea89a758740476b85f | Apache-2.0 |
| swift-collections | 1.3.0 | 7b847a3b7008b2dc2f47ca3110d8c782fb2e5c7e | Apache-2.0 |
| swift-crypto | 4.2.0 | 6f70fa9eab24c1fd982af18c281c4525d05e3095 | Apache-2.0 |
| swift-jinja | 2.3.2 | f731f03bf746481d4fda07f817c3774390c4d5b9 | Apache-2.0 |
| swift-log | 1.9.1 | 2778fd4e5a12a8aaa30a3ee8285f4ce54c5f3181 | Apache-2.0 |
| swift-transformers | 1.1.8 | f3d5cbfa653dd248ae8c92313453d5fdcfdf049e | Apache-2.0 |
| whisperkit | 0.15.0 | 664e1b5a65296cd957dfdf262cd120ca88f3b24b | MIT |
| yyjson | 0.12.0 | 8b4a38dc994a110abaec8a400615567bd996105f | MIT |

Sparkle remains in the shared project resolution for direct downloads, but the store target does not link or embed it. The artifact evaluator checks that boundary.

Additional evidence still required:

- `AppShow/Libraries/gifski/libgifski.a`: shipped with an AGPLv3 license. Establish exact binary provenance, source correspondence and compatible store distribution rights before release; retain ADR 0008’s open-source decision.
- RNNoise is supplied as a binary Swift package. Its root checkout has no LICENSE file in this snapshot; collect upstream/binary notices and the exact source/build provenance.
- WhisperKit model and tokenizer downloads are separate artifacts with their own revisions, source and license evidence. The package license alone does not settle model distribution rights.
- Preserve third-party notices, embedded-license text and corresponding source obligations for the exact archive. Audit bundled native components within transitive packages, rather than relying only on their root license label.
- Confirm provenance and permitted use of the supplied branding artwork, current screenshots and any demonstration media.

No licensing arrangement, model inventory approval or App Store agreement acceptance was inferred or submitted. [A8 remains open](APP-STORE-EVAL.md).
