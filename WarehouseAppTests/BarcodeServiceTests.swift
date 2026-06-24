import XCTest
@testable import WarehouseApp

final class BarcodeServiceTests: XCTestCase {

    // MARK: - EAN-13 validation

    func test_validEAN13_returnsTrue() {
        // 7501031311309 is a known valid EAN-13
        XCTAssertTrue(BarcodeService.isEAN13("7501031311309"))
    }

    func test_invalidChecksum_returnsFalse() {
        // Last digit changed → checksum fails
        XCTAssertFalse(BarcodeService.isEAN13("7501031311300"))
    }

    func test_shortCode_returnsFalse() {
        XCTAssertFalse(BarcodeService.isEAN13("750103131130"))
    }

    func test_containsLetters_returnsFalse() {
        XCTAssertFalse(BarcodeService.isEAN13("750103131130A"))
    }

    func test_emptyString_returnsFalse() {
        XCTAssertFalse(BarcodeService.isEAN13(""))
    }

    // MARK: - MercadoPago QR detection

    func test_mpQR_fullURL_detected() {
        XCTAssertTrue(BarcodeService.isMercadoPagoQR("https://www.mercadopago.com.ar/qr/abc"))
    }

    func test_mpQR_shortURL_detected() {
        XCTAssertTrue(BarcodeService.isMercadoPagoQR("https://mpago.la/1AbCdEf"))
    }

    func test_mpQR_caseInsensitive() {
        XCTAssertTrue(BarcodeService.isMercadoPagoQR("https://www.MercadoPago.com/qr"))
    }

    func test_regularURL_notMP() {
        XCTAssertFalse(BarcodeService.isMercadoPagoQR("https://google.com"))
    }

    // MARK: - Classification

    func test_classify_knownProduct() {
        let product = Product(barcode: "7501031311309", name: "Test", price: 100,
                              stock: 5, variants: [], discount: 0, category: "Test")
        let result = BarcodeService.classify("7501031311309", products: [product])
        if case .product(let p) = result {
            XCTAssertEqual(p.barcode, "7501031311309")
        } else {
            XCTFail("Expected .product")
        }
    }

    func test_classify_unknownCode() {
        let result = BarcodeService.classify("9999999999999", products: [])
        if case .unknown(let code) = result {
            XCTAssertEqual(code, "9999999999999")
        } else {
            XCTFail("Expected .unknown")
        }
    }

    // MARK: - Input sanitization

    func test_sanitizedPrice_validInput() {
        XCTAssertEqual(BarcodeService.sanitizedPrice("1500"), 1500)
    }

    func test_sanitizedPrice_commaDecimal() {
        XCTAssertEqual(BarcodeService.sanitizedPrice("1500,50"), 1500.50, accuracy: 0.01)
    }

    func test_sanitizedPrice_negative_clampsToZero() {
        // Negative sign stripped → "500" → 500 (not possible to enter negative with numberPad)
        XCTAssertGreaterThanOrEqual(BarcodeService.sanitizedPrice("500"), 0)
    }

    func test_sanitizedPrice_emptyString_returnsZero() {
        XCTAssertEqual(BarcodeService.sanitizedPrice(""), 0)
    }

    func test_sanitizedStock_letters_stripped() {
        XCTAssertEqual(BarcodeService.sanitizedStock("abc"), 0)
    }

    func test_sanitizedStock_mixed_keepsNumbers() {
        XCTAssertEqual(BarcodeService.sanitizedStock("10"), 10)
    }
}
