

CREATE TABLE customers (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  nama        VARCHAR(100) NOT NULL,
  no_hp       VARCHAR(20) NOT NULL,
  alamat      TEXT,
  created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE service_orders (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  nomor_tiket       VARCHAR(30) UNIQUE NOT NULL, -- e.g. SRV-20250412-001
  customer_id       UUID NOT NULL REFERENCES customers(id),
  technician_id     UUID NOT NULL REFERENCES technicians(id),

  -- Data perangkat
  jenis_perangkat   VARCHAR(20) NOT NULL,         -- Komputer / Laptop / HP
  merek_model       VARCHAR(100),
  serial_number     VARCHAR(100),
  kondisi_fisik     TEXT,
  kelengkapan       TEXT,                         -- Charger, casing, dll.
  password_pin      VARCHAR(50),

  -- Keluhan & diagnosa
  keluhan           TEXT NOT NULL,
  diagnosa          TEXT,
  jenis_service     VARCHAR(200),
  prioritas         VARCHAR(20) DEFAULT 'normal', -- normal / urgent / express

  -- Biaya
  estimasi_biaya    DECIMAL(12,2),
  biaya_akhir       DECIMAL(12,2),
  status_bayar      VARCHAR(20) DEFAULT 'belum',  -- belum / dp / lunas
  nominal_dp        DECIMAL(12,2),

  -- Status & waktu
  status_service    VARCHAR(30) DEFAULT 'masuk',
  -- masuk → diagnosa → pengerjaan → tunggu_sparepart → selesai → diambil
  tgl_masuk         TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  estimasi_selesai  TIMESTAMP,
  tgl_selesai       TIMESTAMP,
  tgl_diambil       TIMESTAMP
);

CREATE TABLE technicians (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name                  VARCHAR(100) NOT NULL,
  email                 VARCHAR(150) UNIQUE NOT NULL,
  password              VARCHAR(255),                    -- hashed, nullable jika pakai biometrik only

  -- Profile
  avatar_url              TEXT,
  avatar_path             VARCHAR(500),

  -- PIN
  pin_hash              VARCHAR(255),                    -- hashed PIN (4-6 digit)
  pin_attempts          SMALLINT DEFAULT 0,              -- counter salah input PIN
  pin_locked_until      TIMESTAMP,                       -- lockout sementara jika terlalu banyak salah

  -- Biometrik (fingerprint)
  biometric_enabled     BOOLEAN DEFAULT FALSE,
  biometric_public_key  TEXT,                            -- public key dari WebAuthn / FIDO2
  biometric_credential_id TEXT,                          -- credential ID dari device

  -- Status akun
  is_active             BOOLEAN DEFAULT TRUE,
  last_login_at         TIMESTAMP,
  created_at            TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at            TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE UNIQUE INDEX idx_technicians_email ON technicians(email);
CREATE INDEX idx_technicians_credential  ON technicians(biometric_credential_id);

-- Foto kondisi perangkat
CREATE TABLE service_photos (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id     UUID NOT NULL REFERENCES service_orders(id) ON DELETE CASCADE,
  url_foto     TEXT NOT NULL,
  keterangan   VARCHAR(100),
  uploaded_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Log notifikasi ke pelanggan
CREATE TABLE notifications (
  id        UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id  UUID NOT NULL REFERENCES service_orders(id) ON DELETE CASCADE,
  channel   VARCHAR(20) NOT NULL,              -- whatsapp / sms
  pesan     TEXT NOT NULL,
  status    VARCHAR(20) DEFAULT 'pending',     -- pending / sent / failed
  sent_at   TIMESTAMP
);

-- Riwayat perubahan status
CREATE TABLE status_logs (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id     UUID NOT NULL REFERENCES service_orders(id) ON DELETE CASCADE,
  status_lama  VARCHAR(30),
  status_baru  VARCHAR(30) NOT NULL,
  catatan      TEXT,
  changed_at   TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);