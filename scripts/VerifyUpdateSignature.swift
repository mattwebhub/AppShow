import CryptoKit
import Foundation

let arguments = CommandLine.arguments
if arguments.count != 4 {
  fputs("Expected public key, signature and archive path.\n", stderr)
  exit(1)
}
guard let publicData = Data(base64Encoded: arguments[1]),
  let signature = Data(base64Encoded: arguments[2]),
  let key = try? Curve25519.Signing.PublicKey(rawRepresentation: publicData),
  let archive = try? Data(contentsOf: URL(fileURLWithPath: arguments[3]), options: .mappedIfSafe),
  key.isValidSignature(signature, for: archive)
else {
  fputs("Update signature does not match the archive and the app's public key.\n", stderr)
  exit(1)
}
