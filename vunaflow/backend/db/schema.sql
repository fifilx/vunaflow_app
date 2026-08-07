-- ============================================================
-- VunaFlow Database Schema (PostgreSQL)
-- ============================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ---------- ENUMS ----------
CREATE TYPE user_role AS ENUM ('client', 'staff', 'admin');
CREATE TYPE loan_status AS ENUM (
  'submitted',
  'under_review',
  'documents_verified',
  'approved',
  'rejected',
  'disbursed'
);
CREATE TYPE document_type AS ENUM ('national_id', 'title_deed', 'collateral', 'other');
CREATE TYPE staff_status AS ENUM ('active', 'disabled');

-- ---------- BRANCHES ----------
CREATE TABLE branches (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name VARCHAR(150) NOT NULL,
  code VARCHAR(20) UNIQUE NOT NULL,
  county VARCHAR(100),
  address TEXT,
  phone VARCHAR(30),
  created_at TIMESTAMPTZ DEFAULT now()
);

-- ---------- USERS (base auth table for both client & staff) ----------
CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  email VARCHAR(150) UNIQUE NOT NULL,
  phone VARCHAR(30) UNIQUE,
  password_hash TEXT NOT NULL,
  role user_role NOT NULL DEFAULT 'client',
  full_name VARCHAR(150) NOT NULL,
  branch_id UUID REFERENCES branches(id),
  is_active BOOLEAN DEFAULT true,
  reset_token TEXT,
  reset_token_expires TIMESTAMPTZ,
  security_question_1 VARCHAR(255),
  security_answer_1_hash TEXT,
  security_question_2 VARCHAR(255),
  security_answer_2_hash TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- ---------- STAFF PROFILE (extra staff-only info) ----------
CREATE TABLE staff_profiles (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID UNIQUE NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  employee_no VARCHAR(50),
  department VARCHAR(100),
  status staff_status DEFAULT 'active',
  created_at TIMESTAMPTZ DEFAULT now()
);

-- ---------- FARMER (CLIENT) PROFILE ----------
CREATE TABLE farmer_profiles (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID UNIQUE NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  national_id VARCHAR(30) CHECK (national_id IS NULL OR national_id ~ '^[0-9]{7,8}$'),
  date_of_birth DATE,
  gender VARCHAR(20),
  address TEXT,
  county VARCHAR(100),
  -- farm information
  farm_location VARCHAR(200),
  farm_size_acres NUMERIC(10,2),
  primary_crop VARCHAR(100),
  years_farming INTEGER,
  has_collateral BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- ---------- LOAN APPLICATIONS ----------
CREATE TABLE loan_applications (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  client_id UUID NOT NULL REFERENCES users(id),
  branch_id UUID REFERENCES branches(id),
  amount_requested NUMERIC(14,2) NOT NULL CHECK (amount_requested >= 100000),
  purpose VARCHAR(255) NOT NULL,
  repayment_period_months INTEGER NOT NULL CHECK (repayment_period_months > 0),
  status loan_status NOT NULL DEFAULT 'submitted',
  eligibility_result VARCHAR(50),
  reviewed_by UUID REFERENCES users(id),
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_loan_client ON loan_applications(client_id);
CREATE INDEX idx_loan_status ON loan_applications(status);
CREATE INDEX idx_loan_branch ON loan_applications(branch_id);

-- ---------- LOAN STATUS HISTORY (audit trail for tracking) ----------
CREATE TABLE loan_status_history (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  loan_id UUID NOT NULL REFERENCES loan_applications(id) ON DELETE CASCADE,
  status loan_status NOT NULL,
  changed_by UUID REFERENCES users(id),
  comment TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- ---------- DOCUMENTS ----------
CREATE TABLE documents (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  loan_id UUID REFERENCES loan_applications(id) ON DELETE CASCADE,
  client_id UUID NOT NULL REFERENCES users(id),
  doc_type document_type NOT NULL,
  file_path TEXT NOT NULL,
  original_filename VARCHAR(255),
  uploaded_at TIMESTAMPTZ DEFAULT now()
);

-- ---------- NOTIFICATIONS ----------
CREATE TABLE notifications (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  title VARCHAR(150) NOT NULL,
  message TEXT NOT NULL,
  is_read BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_notifications_user ON notifications(user_id, is_read);

-- ---------- SIMULATED: FARMING ADVICE ----------
CREATE TABLE farming_advice (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  crop VARCHAR(100) NOT NULL,
  advice TEXT NOT NULL
);

-- ---------- SIMULATED: CHATBOT FAQ (bilingual: English + Swahili) ----------
CREATE TABLE faqs (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  keyword VARCHAR(100) NOT NULL,
  keyword_sw VARCHAR(100),
  question VARCHAR(255) NOT NULL,
  question_sw VARCHAR(255),
  answer TEXT NOT NULL,
  answer_sw TEXT
);

-- ============================================================
-- SEED DATA
-- ============================================================

-- Real AFC branch network, sourced from AFC's published branch/contact
-- listings (agrifinance.org and public directories), covering all six
-- AFC regions. AFC's own site cites 48 branches nationwide; this seed
-- includes the 42 individually confirmed branches plus Head Office (43
-- total). Staff/admin users can add any remaining branches from the
-- Admin tab in the app (Manage Branches) without needing a code change.
INSERT INTO branches (name, code, county, address, phone) VALUES
('Head Office', 'HQ-NRB', 'Nairobi', 'Development House, Moi Avenue, Nairobi', '0704 153 773'),
-- Central Rift Region
('Nakuru Branch', 'NKR-01', 'Nakuru', 'Kijabe Road, Nakuru', '0711 362 775'),
('Bomet Branch', 'BMT-01', 'Bomet', 'Sotik-Narok Road, Bomet', '0773 554 362'),
('Molo Branch', 'MLO-01', 'Nakuru', 'Njoro-Molo Road, Molo', '020 217 2732'),
('Naivasha Branch', 'NVS-01', 'Nakuru', 'Kariuki-Chotara Road, Naivasha', '050 2020 463'),
('Kericho Branch', 'KCH-01', 'Kericho', 'Temple Road, Kericho', '0775 798 906'),
('Eldama Ravine Branch', 'ELR-01', 'Baringo', 'Maji Mazuri Road, Eldama Ravine', '0774 496 380'),
('Kabarnet Branch', 'KBT-01', 'Baringo', 'Kabarnet-Eldoret Road, Kabarnet', '0705 659 272'),
('Narok Branch', 'NRK-01', 'Narok', 'Nairobi-Narok Road, Narok', '0770 567 277'),
('Ngong Branch', 'NGG-01', 'Kajiado', 'Ngong-Kiserian Road, Ngong', '0723 919 321'),
('Kajiado Branch', 'KJD-01', 'Kajiado', 'Main Town Road, Kajiado', '0729 630 066'),
('Loitokitok Branch', 'LTK-01', 'Kajiado', 'Elassit Road, Loitokitok', '0717 628 628'),
-- Coast Region
('Kilifi Branch', 'KLF-01', 'Kilifi', 'Near KCB Bank, Kilifi', '0772 125 313'),
('Ukunda Branch', 'UKD-01', 'Kwale', 'Mombasa-Lunga Lunga Road, Ukunda', '0772 561 510'),
('Bura Branch', 'BUR-01', 'Tana River', 'NIB Offices, Bura', '0717 806 016'),
('Mpeketoni Branch', 'MPK-01', 'Lamu', 'Opposite Kenyatta Primary, Mpeketoni', '0701 867 478'),
('Hola Branch', 'HOL-01', 'Tana River', 'NIB Offices, Hola', '0717 806 016'),
('Taita Taveta Branch', 'TTV-01', 'Taita Taveta', 'Eldoro Village, Taita Taveta', '0740 571 517'),
-- Eastern Region
('Wote Branch', 'WOT-01', 'Makueni', 'Ngei Road, Wote', '020 267 5807'),
('Machakos Branch', 'MCK-01', 'Machakos', 'Ngei Road, Machakos', '020 262 4249'),
-- Mount Kenya Region
('Kiambu Branch', 'KMB-01', 'Kiambu', 'Kiambu Town', '0705 318 963'),
('Nyeri Branch', 'NYR-01', 'Nyeri', 'Bondeni Road, Nyeri', '0771 285 498'),
('Chogoria Branch', 'CHG-01', 'Tharaka-Nithi', 'Meru-Kaveche Road, Chogoria', '0770 012 356'),
('Thika Branch', 'THK-01', 'Kiambu', 'Karanja Street, Thika', '0733 865 181'),
('Karatina Branch', 'KRT-01', 'Nyeri', 'Industrial Area, Karatina', '061 457 2008'),
('Muranga Branch', 'MRG-01', 'Murang''a', 'Huru Highway, Muranga', '0721 949 749'),
('Nanyuki Branch', 'NYK-01', 'Laikipia', 'Bidha Bora Road, Nanyuki', '051 801 0937'),
('Kerugoya Branch', 'KRG-01', 'Kirinyaga', 'Kirinyaga Building, Kerugoya', '0770 354 963'),
('Meru Branch', 'MRU-01', 'Meru', 'Meru-Makutano Road, Meru', '0720 978 382'),
('Nyahururu Branch', 'NYH-01', 'Laikipia', 'Nyeri-Nyahururu Road, Nyahururu', '065 203 2223'),
('Embu Branch', 'EMB-01', 'Embu', 'Embu Road, Embu', '0703 125 304'),
('Maralal Branch', 'MRL-01', 'Samburu', 'Maralal Town', '0721 395 054'),
-- North Rift Region
('Eldoret Branch', 'ELD-01', 'Uasin Gishu', 'Eldoret-Unga Road, Eldoret', '053 206 1432'),
('Kitale Branch', 'KTL-01', 'Trans Nzoia', 'Makasembo Road, Kitale', '0786 629 946'),
('Kapsabet Branch', 'KPS-01', 'Nandi', 'Opposite Post Office, Kapsabet', '020 232 0309'),
('Turbo Branch', 'TRB-01', 'Uasin Gishu', 'Uganda Road, Turbo', '0711 444 149'),
('Ziwa Branch', 'ZIW-01', 'Uasin Gishu', 'Sirikwa Centre, Ziwa', '0712 353 974'),
('Iten Branch', 'ITN-01', 'Elgeyo-Marakwet', 'Off Iten-Kapsowar Street, Iten', '0773 568 265'),
-- Nyanza Western Region
('Kakamega Branch', 'KKG-01', 'Kakamega', 'Kakamega Town', '020 633 695'),
('Kisii Branch', 'KSI-01', 'Kisii', 'NCPB House, Kisii', '020 803 3032'),
('Migori Branch', 'MGR-01', 'Migori', 'Administration Road, Migori', '020 235 2075'),
('Kisumu Branch', 'KSM-01', 'Kisumu', 'Oginga Odinga Road, Kisumu', '057 252 3944'),
('Bondo Branch', 'BND-01', 'Siaya', 'Bondo Town', '057 251 2412');

INSERT INTO farming_advice (crop, advice) VALUES
('Maize', 'Plant before the onset of the rainy season and use certified seed for higher yields.'),
('Coffee', 'Prune trees after harvest and mulch to conserve soil moisture.'),
('Tea', 'Pluck regularly every 7-14 days and apply fertilizer after pruning cycles.'),
('Beans', 'Rotate with cereals to improve soil nitrogen and reduce disease build-up.'),
('Dairy Farming', 'Ensure a consistent supply of clean water and balanced feed rations for optimal milk yield.'),
('Horticulture', 'Use drip irrigation to conserve water and reduce fungal disease pressure.');

INSERT INTO faqs (keyword, keyword_sw, question, question_sw, answer, answer_sw) VALUES
('apply', 'omba',
 'How do I apply for a loan?', 'Ninawezaje kuomba mkopo?',
 'Register an account, complete your farmer profile, then go to Loan Application, fill in the form and submit it along with your required documents.',
 'Jisajili kwa akaunti, kamilisha wasifu wako wa mkulima, kisha nenda kwenye Maombi ya Mkopo, jaza fomu na uwasilishe pamoja na hati zinazohitajika.'),
('documents', 'hati',
 'What documents do I need?', 'Ni hati gani ninazohitaji?',
 'You need a valid National ID, a Title Deed (or proof of land ownership), and any collateral documents relevant to your loan.',
 'Utahitaji Kitambulisho cha Taifa halali, Hati ya Umiliki wa Ardhi (au uthibitisho wa umiliki), na hati zozote za dhamana zinazohusiana na mkopo wako.'),
('interest', 'riba',
 'What is the interest rate?', 'Kiwango cha riba ni kipi?',
 'Interest rates vary by loan product. Please contact your nearest AFC branch or your loan officer for the current applicable rate.',
 'Viwango vya riba hutofautiana kulingana na aina ya mkopo. Tafadhali wasiliana na tawi lako la karibu la AFC au afisa wako wa mkopo kwa kiwango cha sasa.'),
('minimum', 'kiwango cha chini',
 'What is the minimum loan amount?', 'Kiwango cha chini cha mkopo ni kipi?',
 'The minimum loan amount you can apply for is KSh 100,000.',
 'Kiwango cha chini cha mkopo unachoweza kuomba ni KSh 100,000.'),
('time', 'muda',
 'How long does approval take?', 'Idhini huchukua muda gani?',
 'Once all documents are verified, review typically takes a few business days depending on branch workload.',
 'Baada ya hati zote kuthibitishwa, ukaguzi kwa kawaida huchukua siku chache za kazi kutegemea shughuli za tawi.'),
('track', 'fuatilia',
 'How can I track my application?', 'Ninawezaje kufuatilia maombi yangu?',
 'Log in to your Client Dashboard and open Loan Tracking to see the current status of your application.',
 'Ingia kwenye Dashibodi yako ya Mteja na fungua Ufuatiliaji wa Mkopo kuona hali ya sasa ya maombi yako.'),
('eligibility', 'sifa',
 'Am I eligible for a loan?', 'Je, ninastahili mkopo?',
 'Use the Eligibility Checker in the app. Generally you need to be 18+, have at least 2 acres of farm land, request no more than KSh 1,000,000, and have collateral.',
 'Tumia Kikagua Sifa kwenye programu. Kwa ujumla unahitaji kuwa na miaka 18+, angalau ekari 2 za shamba, kuomba si zaidi ya KSh 1,000,000, na kuwa na dhamana.'),
('branch', 'tawi',
 'How do I choose a branch?', 'Ninawezaje kuchagua tawi?',
 'During registration or in your profile, you can select the AFC branch nearest to you from the list provided. When you apply for a loan you also choose the branch that will handle your application.',
 'Wakati wa kujisajili au kwenye wasifu wako, unaweza kuchagua tawi la AFC lililo karibu nawe kutoka kwenye orodha iliyotolewa. Unapoomba mkopo pia huchagua tawi litakaloshughulikia maombi yako.'),
('contact', 'wasiliana',
 'How do I contact AFC?', 'Ninawezaje kuwasiliana na AFC?',
 'You can reach AFC via the Contact section on our landing page, or visit your nearest branch during office hours (Mon-Fri, 8am-5pm).',
 'Unaweza kuwasiliana na AFC kupitia sehemu ya Mawasiliano kwenye ukurasa wetu, au tembelea tawi lako la karibu wakati wa masaa ya kazi (Jumatatu-Ijumaa, 8am-5pm).');
