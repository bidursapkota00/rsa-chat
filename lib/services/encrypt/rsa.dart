import 'dart:math';

class RSAKeyPair {
  final BigInt publicKey;
  final BigInt privateKey;
  final BigInt modulus;

  RSAKeyPair({
    required this.publicKey,
    required this.privateKey,
    required this.modulus,
  });
}

class RSA {
  // Generate large prime numbers
  BigInt _generatePrime() {
    final rng = Random.secure();
    while (true) {
      // Generate a random prime number (simplified for illustration purposes)
      // Generates a random integer between 0 + 500 and 4999 + 500
      BigInt prime =
          BigInt.from(rng.nextInt(1000) + 200); // Start from a higher number
      if (_isPrime(prime)) {
        return prime;
      }
    }
  }

  // Check if a number is prime (simplified version)
  bool _isPrime(BigInt n) {
    if (n <= BigInt.one) return false;
    if (n == BigInt.two) return true;
    if (n.isEven) return false;
    for (BigInt i = BigInt.from(3); i * i <= n; i += BigInt.two) {
      if (n % i == BigInt.zero) return false;
    }
    return true;
  }

  // Compute the greatest common divisor (GCD) of two numbers
  BigInt _gcd(BigInt a, BigInt b) {
    while (b != BigInt.zero) {
      BigInt temp = b;
      b = a % b;
      a = temp;
    }
    return a;
  }

  // Find modular inverse of a number (using extended Euclidean algorithm)
  // The modular inverse of 𝑎 under modulo m is a number x such that:
  // (a x x) mod m = 1
  // The modular inverse exists only if a and m are coprime: ie GCD(a, m) = 1
  BigInt _modInverse(BigInt a, BigInt m) {
    BigInt m0 = m;
    BigInt y = BigInt.zero;
    BigInt x = BigInt.one;

    if (m == BigInt.one) return BigInt.zero;

    while (a > BigInt.one) {
      BigInt q = a ~/ m;
      BigInt t = m;

      // m is remainder now, process same as Euclid's algorithm
      m = a % m;
      a = t;
      t = y;

      // Update y and x
      y = x - q * y;
      x = t;
    }

    if (x < BigInt.zero) x += m0;

    return x;
  }

  // Generate the RSA key pair
  RSAKeyPair generateKeyPair() {
    // Step 1: Choose two large prime numbers, p and q
    BigInt p = _generatePrime();
    BigInt q = _generatePrime();

    // Step 2: Compute N = p * q
    BigInt N = p * q;

    // Step 3: Compute Euler's totient function φ(N) = (p - 1) * (q - 1)
    BigInt phiN = (p - BigInt.one) * (q - BigInt.one);

    // Step 4: Choose a public exponent e (must be coprime with φ(N))
    BigInt e = BigInt.from(211);
    while (_gcd(e, phiN) != BigInt.one) {
      e += BigInt.from(2); // Try different values of e if GCD is not 1
    }

    // Step 5: Compute the private exponent d such that (d * e) % φ(N) = 1
    BigInt d = _modInverse(e, phiN);

    // Step 6: Return the key pair (publicKey, privateKey, modulus)
    return RSAKeyPair(
      publicKey: e,
      privateKey: d,
      modulus: N,
    );
  }

  // Encrypt a message using the public key
  String encrypt(String message, BigInt publicKey, BigInt modulus) {
    List<String> encryptedMessage = [];
    for (int i = 0; i < message.length; i++) {
      // Convert the character to its ASCII value
      BigInt charValue = BigInt.from(message.codeUnitAt(i));

      // Encrypt the ASCII value using RSA: (charValue ^ publicKey) % modulus
      BigInt encryptedChar = charValue.modPow(publicKey, modulus);
      encryptedMessage.add(encryptedChar.toString());
    }
    // Join encrypted numbers with commas
    return encryptedMessage.join(',');
  }

// Decrypt a comma-separated string of numbers using the private key
  String decrypt(String cipherText, BigInt privateKey, BigInt modulus) {
    // Split the comma-separated string into a list of encrypted BigInt values
    List<String> encryptedNumbers = cipherText.split(',');
    StringBuffer decryptedMessage = StringBuffer();

    print('hello1');
    print('hello2');
    print('hello3');
    print('hello4');
    print(privateKey);
    print(encryptedNumbers.toString());

    for (String encryptedNumber in encryptedNumbers) {
      // Convert each number back to BigInt
      BigInt encryptedChar = BigInt.parse(encryptedNumber);

      // Decrypt the encrypted number: (encryptedChar ^ privateKey) % modulus
      BigInt decryptedValue = encryptedChar.modPow(privateKey, modulus);

      // Convert the decrypted value back to a character
      decryptedMessage.write(String.fromCharCode(decryptedValue.toInt()));
    }

    return decryptedMessage.toString();
  }
}
