#!/usr/bin/env python3
"""
Seed script: Modelový test A2 druhy (NPI ČR, platný od dubna 2026)

Creates:
  - Course "Ôn thi A2 Trvalý pobyt — Modelový test 2"
  - Modules per skill (Mluvení / Psaní / Poslech / Čtení)
  - Skills per module
  - Exercises (pool=course) per skill
  - Exercises (pool=exam) for MockTest sections
  - MockTest "speaking" (Mluvení, 40 pts)
  - MockTest "pisemna" (Čtení+Psaní+Poslech, 70 pts)

Usage:
  make dev-backend          # start backend
  python3 scripts/seed-modelovy-test-2.py
"""

import json, sys, time
import urllib.request, urllib.error

BASE = "http://localhost:8080"
ADMIN_EMAIL = "admin@example.com"
ADMIN_PASSWORD = "demo123"

# ──────────────────────────────────────────────────────────────────────────────
def req(method, path, body=None, token=None):
    url = BASE + path
    data = json.dumps(body).encode() if body else None
    headers = {"Content-Type": "application/json"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    r = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(r) as resp:
            return json.loads(resp.read())
    except urllib.error.HTTPError as e:
        err = e.read().decode()
        print(f"  ERROR {e.code} {method} {path}: {err[:200]}", file=sys.stderr)
        return None

def login():
    r = req("POST", "/v1/auth/login", {"email": ADMIN_EMAIL, "password": ADMIN_PASSWORD})
    if not r:
        sys.exit("Login failed — is the backend running? Run: make dev-backend")
    t = r.get("data", {}).get("access_token") or r.get("data", {}).get("token")
    if not t:
        sys.exit(f"No token in response: {r}")
    print(f"✓ Logged in as {ADMIN_EMAIL}")
    return t

# ──────────────────────────────────────────────────────────────────────────────

def create_course(token, title, slug, description):
    r = req("POST", "/v1/admin/courses", {
        "slug": slug, "title": title, "description": description,
        "status": "published", "sequence_no": 1
    }, token)
    if not r:
        return None
    course = r.get("data", {})
    print(f"  ✓ Course: {course.get('title')} [{course.get('id')}]")
    return course

def create_module(token, course_id, slug, title, description, seq):
    r = req("POST", "/v1/admin/modules", {
        "course_id": course_id, "slug": slug, "title": title,
        "description": description, "module_kind": "practice",
        "sequence_no": seq, "status": "published"
    }, token)
    if not r:
        return None
    m = r.get("data", {})
    print(f"    ✓ Module: {m.get('title')} [{m.get('id')}]")
    return m

def create_skill(token, module_id, skill_kind, title, seq):
    r = req("POST", "/v1/admin/skills", {
        "module_id": module_id, "skill_kind": skill_kind,
        "title": title, "sequence_no": seq, "status": "published"
    }, token)
    if not r:
        return None
    s = r.get("data", {})
    print(f"      ✓ Skill: {s.get('title')} [{s.get('id')}]")
    return s

def create_exercise(token, ex):
    r = req("POST", "/v1/admin/exercises", ex, token)
    if not r:
        return None
    e = r.get("data", {})
    print(f"        ✓ Exercise [{ex.get('pool','?')}] {e.get('exercise_type')} — {e.get('title')} [{e.get('id')}]")
    return e

def create_mock_test(token, title, description, duration, status, session_type, sections):
    r = req("POST", "/v1/admin/mock-tests", {
        "title": title, "description": description,
        "estimated_duration_minutes": duration,
        "status": status, "session_type": session_type,
        "sections": sections
    }, token)
    if not r:
        return None
    mt = r.get("data", {})
    print(f"  ✓ MockTest [{session_type}]: {mt.get('title')} [{mt.get('id')}]")
    return mt

# ──────────────────────────────────────────────────────────────────────────────
# Exercise content — from Modelový test A2, NPI ČR (platný od dubna 2026)
# Source: Modelovy-test-novy-format-A2-druhy.pdf (OCR 2026-04-27)
# ──────────────────────────────────────────────────────────────────────────────

def ex_uloha1(pool, skill_id=None, module_id=None):
    return {
        "exercise_type": "uloha_1_topic_answers",
        "title": "Úloha 1 — Otázky k tématu",
        "short_instruction": "Odpovězte na otázky examinátora.",
        "learner_instruction": "Trả lời các câu hỏi của giám khảo về chủ đề được đưa ra.",
        "estimated_duration_sec": 120, "prep_time_sec": 10,
        "recording_time_limit_sec": 90,
        "sample_answer_enabled": True,
        "status": "published", "pool": pool,
        **({"skill_id": skill_id, "module_id": module_id} if skill_id else {}),
        "questions": [
            "Kde bydlíte? Popište svoje bydliště.",
            "Co děláte ve volném čase?",
            "Jak cestujete do práce nebo do školy?",
            "Jaké jídlo máte rádi? Co vaříte doma?",
            "Mluvte o svojí rodině.",
            "Jaké počasí máte rádi a proč?",
            "Popište svůj typický den.",
            "Co plánujete na víkend?"
        ]
    }

def ex_uloha2(pool, skill_id=None, module_id=None):
    return {
        "exercise_type": "uloha_2_dialogue_questions",
        "title": "Úloha 2 — Zjišťování informací",
        "short_instruction": "Zeptejte se examinátora na potřebné informace.",
        "learner_instruction": "Bạn cần hỏi giám khảo để lấy các thông tin còn thiếu.",
        "estimated_duration_sec": 150, "prep_time_sec": 15,
        "recording_time_limit_sec": 90,
        "sample_answer_enabled": True,
        "status": "published", "pool": pool,
        **({"skill_id": skill_id, "module_id": module_id} if skill_id else {}),
        "detail": {
            "scenario_title": "Kino Světozor",
            "scenario_prompt": "Chcete jít do kina na nový film. Potřebujete zjistit základní informace.",
            "required_info_slots": [
                {"slot_key": "cas", "label": "Čas představení", "sample_question": "V kolik hodin film začíná?"},
                {"slot_key": "cena", "label": "Cena lístku", "sample_question": "Kolik stojí jeden lístek?"},
                {"slot_key": "misto", "label": "Adresa kina", "sample_question": "Kde kino je?"},
                {"slot_key": "rezervace", "label": "Možnost rezervace", "sample_question": "Mohu si lístek rezervovat online?"}
            ],
            "custom_question_hint": "Zeptejte se ještě na jednu věc (třeba na parkoviště nebo restauraci v blízkosti)."
        }
    }

def ex_uloha3(pool, skill_id=None, module_id=None):
    return {
        "exercise_type": "uloha_3_story_narration",
        "title": "Úloha 3 — Vyprávění příběhu",
        "short_instruction": "Podle obrázků vyprávějte krátký příběh.",
        "learner_instruction": "Kể câu chuyện ngắn dựa vào các hình ảnh. Dùng thì quá khứ.",
        "estimated_duration_sec": 150, "prep_time_sec": 20,
        "recording_time_limit_sec": 90,
        "sample_answer_enabled": True,
        "status": "published", "pool": pool,
        **({"skill_id": skill_id, "module_id": module_id} if skill_id else {}),
        "detail": {
            "story_title": "Nákup televize",
            "image_asset_ids": ["placeholder-tv-1", "placeholder-tv-2", "placeholder-tv-3", "placeholder-tv-4"],
            "narrative_checkpoints": [
                "Otec a syn šli do obchodu s elektronikou.",
                "Dívali se na různé televize a porovnávali je.",
                "Syn ukázal na velkou televizi, která se mu líbila.",
                "Zaplatili a odvezli televizi domů autem."
            ],
            "grammar_focus": ["past_tense", "perfective_verbs"]
        }
    }

def ex_uloha4(pool, skill_id=None, module_id=None):
    return {
        "exercise_type": "uloha_4_choice_reasoning",
        "title": "Úloha 4 — Výběr a zdůvodnění",
        "short_instruction": "Vyberte jednu možnost a zdůvodněte svůj výběr.",
        "learner_instruction": "Chọn 1 trong 3 phương án và giải thích lý do. Dùng 'protože'.",
        "estimated_duration_sec": 120, "prep_time_sec": 15,
        "recording_time_limit_sec": 60,
        "sample_answer_enabled": True,
        "status": "published", "pool": pool,
        **({"skill_id": skill_id, "module_id": module_id} if skill_id else {}),
        "detail": {
            "scenario_prompt": "Hledáte ubytování v Praze na jeden týden. Který typ ubytování si vyberete?",
            "options": [
                {"option_key": "hotel", "label": "Hotel", "description": "Pohodlný, ale dražší. Snídaně v ceně."},
                {"option_key": "airbnb", "label": "Airbnb byt", "description": "Levnější, vlastní kuchyně, jako doma."},
                {"option_key": "hostel", "label": "Hostel", "description": "Nejlevnější, sdílený pokoj, noví přátelé."}
            ],
            "expected_reasoning_axes": ["price", "comfort", "location", "food"]
        }
    }

def ex_psani1(pool, skill_id=None, module_id=None):
    return {
        "exercise_type": "psani_1_formular",
        "title": "Psaní 1 — Formulář spokojenosti e-shopu",
        "short_instruction": "Odpovězte na otázky v dotazníku. Každá odpověď min. 10 slov.",
        "learner_instruction": "Viết câu trả lời đầy đủ câu cho mỗi câu hỏi, ít nhất 10 từ mỗi câu.",
        "estimated_duration_sec": 900,
        "sample_answer_enabled": False,
        "status": "published", "pool": pool,
        **({"skill_id": skill_id, "module_id": module_id} if skill_id else {}),
        "detail": {
            "questions": [
                "Jak jste získal/a informace o našem e-shopu?",
                "Proč v našem e-shopu nakupujete?",
                "Které služby nebo informace vám v našem e-shopu chybí?"
            ],
            "min_words": 10
        }
    }

def ex_psani2(pool, skill_id=None, module_id=None):
    return {
        "exercise_type": "psani_2_email",
        "title": "Psaní 2 — E-mail o dovolené",
        "short_instruction": "Napište e-mail kamarádce o vaší dovolené. Min. 35 slov.",
        "learner_instruction": "Viết email cho bạn về kỳ nghỉ. Đề cập đến tất cả 5 chủ đề. Ít nhất 35 từ.",
        "estimated_duration_sec": 1500,
        "sample_answer_enabled": False,
        "status": "published", "pool": pool,
        **({"skill_id": skill_id, "module_id": module_id} if skill_id else {}),
        "detail": {
            "prompt": "Jste na dovolené a chcete napsat své kamarádce. Napište jí pozdrav a další informace. Napište minimálně 35 slov. Musíte napsat minimálně 1 větu jako pozdrav + 1 větu ke každému obrázku (1-5).",
            "topics": ["KDE JSTE?", "JAK DLOUHO TAM JSTE?", "KDE BYDLÍTE?", "CO DĚLÁTE DOPOLEDNE?", "CO DĚLÁTE ODPOLEDNE?"],
            "image_asset_ids": [],
            "min_words": 35
        }
    }

def ex_poslech1(pool, skill_id=None, module_id=None):
    return {
        "exercise_type": "poslech_1",
        "title": "Poslech 1 — Krátké rozhovory",
        "short_instruction": "Poslechněte si 5 krátkých dialogů a vyberte správnou odpověď A-D.",
        "learner_instruction": "Nghe 5 đoạn hội thoại ngắn và chọn đáp án A-D cho mỗi câu.",
        "estimated_duration_sec": 900,
        "sample_answer_enabled": False,
        "status": "published", "pool": pool,
        **({"skill_id": skill_id, "module_id": module_id} if skill_id else {}),
        "detail": {
            "items": [
                {"question_no": 1, "audio_source": {"segments": [{"text": "Žena: Promiňte, kdy jede příští autobus do centra? Muž: Za deset minut, u zastávky naproti."}]}, "options": [{"key": "A", "text": "Za 5 minut"}, {"key": "B", "text": "Za 10 minut"}, {"key": "C", "text": "Za 15 minut"}, {"key": "D", "text": "Za 20 minut"}]},
                {"question_no": 2, "audio_source": {"segments": [{"text": "Žena: Kolik stojí ten červený svetr? Prodavač: Tento svetr stojí čtyři sta korun, ale máme slevu dvacet procent."}]}, "options": [{"key": "A", "text": "280 Kč"}, {"key": "B", "text": "320 Kč"}, {"key": "C", "text": "400 Kč"}, {"key": "D", "text": "480 Kč"}]},
                {"question_no": 3, "audio_source": {"segments": [{"text": "Muž: Dobrý den, mám rezervaci na jméno Novák. Recepční: Ano, máte pokoj číslo třiadvacet ve druhém patře."}]}, "options": [{"key": "A", "text": "V prvním patře"}, {"key": "B", "text": "Ve druhém patře"}, {"key": "C", "text": "Ve třetím patře"}, {"key": "D", "text": "V přízemí"}]},
                {"question_no": 4, "audio_source": {"segments": [{"text": "Žena: Kdy máte otevřeno? Muž: V pondělí až pátek od osmi do sedmnácti, v sobotu od devíti do dvanácti."}]}, "options": [{"key": "A", "text": "8:00-17:00 celý týden"}, {"key": "B", "text": "Po-Pá 8-17, So 9-12"}, {"key": "C", "text": "Po-Pá 9-17, So 9-12"}, {"key": "D", "text": "Po-Pá 8-18, So 9-13"}]},
                {"question_no": 5, "audio_source": {"segments": [{"text": "Doktor: Musíte brát tyto tablety třikrát denně po jídle. Pacient: Dobře, děkuji."}]}, "options": [{"key": "A", "text": "Jednou denně"}, {"key": "B", "text": "Dvakrát denně"}, {"key": "C", "text": "Třikrát denně"}, {"key": "D", "text": "Čtyřikrát denně"}]}
            ],
            "correct_answers": {"1": "B", "2": "B", "3": "B", "4": "B", "5": "C"}
        }
    }

def ex_poslech2(pool, skill_id=None, module_id=None):
    return {
        "exercise_type": "poslech_2",
        "title": "Poslech 2 — Krátké texty",
        "short_instruction": "Poslechněte si 5 krátkých textů a vyberte správnou odpověď A-D.",
        "learner_instruction": "Nghe 5 đoạn văn ngắn và chọn đáp án A-D.",
        "estimated_duration_sec": 900,
        "sample_answer_enabled": False,
        "status": "published", "pool": pool,
        **({"skill_id": skill_id, "module_id": module_id} if skill_id else {}),
        "detail": {
            "items": [
                {"question_no": 6, "audio_source": {"segments": [{"text": "Teplota v neděli bude až deset stupňů Celsia. V pondělí se očekává déšť a teploty klesnou na pět stupňů."}]}, "options": [{"key": "A", "text": "Bude hezky"}, {"key": "B", "text": "Bude pršet"}, {"key": "C", "text": "Bude sněžit"}, {"key": "D", "text": "Bude mlha"}]},
                {"question_no": 7, "audio_source": {"segments": [{"text": "V neděli ráno bude zataženo, odpoledne a večer polojasno, místy jasno. Nejvyšší denní teploty tři až pět stupňů Celsia, na horách nula až minus tři."}]}, "options": [{"key": "A", "text": "Celý den jasno"}, {"key": "B", "text": "Ráno zataženo, odpoledne lepší"}, {"key": "C", "text": "Celý den déšť"}, {"key": "D", "text": "Sněžení v horách i níže"}]},
                {"question_no": 8, "audio_source": {"segments": [{"text": "Tento týden jsou v naší restauraci ve speciální nabídce svíčková na smetaně a smažený sýr. Oba pokrmy jsou o patnáct korun levnější."}]}, "options": [{"key": "A", "text": "Restaurace má nové menu"}, {"key": "B", "text": "Restaurace je dnes zavřená"}, {"key": "C", "text": "Jsou speciální ceny na dva pokrmy"}, {"key": "D", "text": "Restaurace hledá zaměstnance"}]},
                {"question_no": 9, "audio_source": {"segments": [{"text": "Páteční vlak z Brna do Prahy odjíždí v sedm čtyřiadvacet z druhého nástupiště. Vlak přijíždí do Prahy v devět padesát."}]}, "options": [{"key": "A", "text": "Vlak odjíždí v 7:24 z nástupiště 1"}, {"key": "B", "text": "Vlak odjíždí v 7:42 z nástupiště 2"}, {"key": "C", "text": "Vlak odjíždí v 7:24 z nástupiště 2"}, {"key": "D", "text": "Vlak odjíždí v 9:50 z nástupiště 2"}]},
                {"question_no": 10, "audio_source": {"segments": [{"text": "Lékárna Bílá labuť informuje, že od příštího týdne budeme mít nové otevírací hodiny. V pondělí, středu a pátek budeme otevřeni do dvaceti hodin."}]}, "options": [{"key": "A", "text": "Lékárna se stěhuje"}, {"key": "B", "text": "Lékárna mění otevírací dobu"}, {"key": "C", "text": "Lékárna se zavírá"}, {"key": "D", "text": "Lékárna hledá farmaceuty"}]}
            ],
            "correct_answers": {"6": "B", "7": "B", "8": "C", "9": "C", "10": "B"}
        }
    }

def ex_poslech3(pool, skill_id=None, module_id=None):
    return {
        "exercise_type": "poslech_3",
        "title": "Poslech 3 — Koníčky (match A-G)",
        "short_instruction": "Poslechněte 5 žen a přiřaďte jejich koníčky z nabídky A-G.",
        "learner_instruction": "Nghe 5 người phụ nữ nói về sở thích và ghép với danh sách A-G.",
        "estimated_duration_sec": 900,
        "sample_answer_enabled": False,
        "status": "published", "pool": pool,
        **({"skill_id": skill_id, "module_id": module_id} if skill_id else {}),
        "detail": {
            "items": [
                {"question_no": 11, "audio_source": {"segments": [{"text": "Jmenuji se Leila. Teď mě nejvíc baví plavání. Chodím do bazénu třikrát týdně."}]}},
                {"question_no": 12, "audio_source": {"segments": [{"text": "Já jsem Dzamila. Ráda vařím různá jídla z celého světa. Mám doma hodně kuchařských knih."}]}},
                {"question_no": 13, "audio_source": {"segments": [{"text": "Jmenuji se Ivona. Mám ráda přírodu a fotografuji ji. Mám doma tisíce fotografií."}]}},
                {"question_no": 14, "audio_source": {"segments": [{"text": "Já jsem Hindi. Hodně čtu. Mám ráda romány a detektivky. Jsem členem knihovny."}]}},
                {"question_no": 15, "audio_source": {"segments": [{"text": "Jmenuji se Nada. Každé ráno běhám v parku. Letos jsem běžela svůj první půlmaraton."}]}}
            ],
            "options": [
                {"key": "A", "label": "běh"},
                {"key": "B", "label": "vaření"},
                {"key": "C", "label": "kreslení"},
                {"key": "D", "label": "sledování televize"},
                {"key": "E", "label": "čtení"},
                {"key": "F", "label": "plavání"},
                {"key": "G", "label": "fotografování"}
            ],
            "correct_answers": {"11": "F", "12": "B", "13": "G", "14": "E", "15": "A"}
        }
    }

def ex_poslech4(pool, skill_id=None, module_id=None):
    return {
        "exercise_type": "poslech_4",
        "title": "Poslech 4 — Nakupování oblečení (choose image A-F)",
        "short_instruction": "Poslechněte 5 dialogů v obchodě. Co chtějí zákazníci?",
        "learner_instruction": "Nghe 5 đoạn hội thoại trong cửa hàng và chọn hình ảnh phù hợp A-F.",
        "estimated_duration_sec": 900,
        "sample_answer_enabled": False,
        "status": "published", "pool": pool,
        **({"skill_id": skill_id, "module_id": module_id} if skill_id else {}),
        "detail": {
            "items": [
                {"question_no": 16, "audio_source": {"segments": [{"speaker": "A", "text": "Paní prodavačko, máte tyhle boty také v bílé barvě, velikost třicet devět?"}, {"speaker": "B", "text": "Počkejte, podívám se. Ano. Mám je. Chcete si je zkusit?"}, {"speaker": "A", "text": "Ne, vezmu si je hned."}]}},
                {"question_no": 17, "audio_source": {"segments": [{"speaker": "A", "text": "Dobrý den, chtěla bych nějaké bavlněné tričko. Máte něco pěkného?"}, {"speaker": "B", "text": "Máme tyhle, jsou velmi populární. V modré, červené nebo bílé."}]}},
                {"question_no": 18, "audio_source": {"segments": [{"speaker": "A", "text": "Hledám nějaké šaty na oslavu. Moje sestra se vdává."}, {"speaker": "B", "text": "Dobře. A chcete dlouhé šaty, nebo krátké šaty?"}, {"speaker": "A", "text": "To je jedno, ale musí být růžové."}]}},
                {"question_no": 19, "audio_source": {"segments": [{"speaker": "A", "text": "Dobrý den, chtěla bych nějaký zimní kabát."}, {"speaker": "B", "text": "Jakou velikost, prosím?"}, {"speaker": "A", "text": "Asi L nebo XL."}]}},
                {"question_no": 20, "audio_source": {"segments": [{"speaker": "A", "text": "Prosím vás, hledám kalhoty na sport. Mám rád pohodlné věci."}, {"speaker": "B", "text": "Tyto jsou skvělé na sport i na volný čas."}]}}
            ],
            "options": [
                {"key": "A", "asset_id": ""},
                {"key": "B", "asset_id": ""},
                {"key": "C", "asset_id": ""},
                {"key": "D", "asset_id": ""},
                {"key": "E", "asset_id": ""},
                {"key": "F", "asset_id": ""}
            ],
            "correct_answers": {"16": "A", "17": "B", "18": "C", "19": "D", "20": "E"}
        }
    }

def ex_poslech5(pool, skill_id=None, module_id=None):
    return {
        "exercise_type": "poslech_5",
        "title": "Poslech 5 — Hlasová zpráva od Evy",
        "short_instruction": "Poslechněte si hlasovou zprávu a odpovězte na otázky.",
        "learner_instruction": "Nghe tin nhắn thoại và điền thông tin. Bạn sẽ nghe 2 lần.",
        "estimated_duration_sec": 900,
        "sample_answer_enabled": False,
        "status": "published", "pool": pool,
        **({"skill_id": skill_id, "module_id": module_id} if skill_id else {}),
        "detail": {
            "audio_source": {
                "segments": [
                    {"text": "Ahoj Lído, tady Eva. Lído, dostala jsem od své sestry Ivany k narozeninám dva lístky na balet. Ivana nemůže a já nechci jít sama. Nechceš jít se mnou? Vím, že máš balet moc ráda. A taky jsme se měsíc neviděly. Co myslíš? Představení je dvacátého třetího dubna, to je v úterý, začátek je v šest hodin večer. Potom můžeme jít na večeři. Znám jednu dobrou restauraci, jmenuje se Klášterní. Píše se to velké ká el dlouhé á eš té krátké e er en měkké dlouhé í. Zvu tě! Ozvi se mi prosím do středy do večera na telefon sedm sedm tři devět tři dva pět nula čtyři. Budu se těšit, ahoj."}
                ]
            },
            "questions": [
                {"question_no": 21, "prompt": "KDO dal Evě lístky?"},
                {"question_no": 22, "prompt": "KOLIKÁTÉHO bude balet?"},
                {"question_no": 23, "prompt": "KTERÝ DEN bude balet?"},
                {"question_no": 24, "prompt": "JAK se jmenuje restaurace?"},
                {"question_no": 25, "prompt": "TELEFON Evy?"}
            ],
            "correct_answers": {
                "21": "sestra Ivana",
                "22": "23",
                "23": "úterý",
                "24": "Klášterní",
                "25": "773932504"
            }
        }
    }

def ex_cteni1(pool, skill_id=None, module_id=None):
    return {
        "exercise_type": "cteni_1",
        "title": "Čtení 1 — Přiřazení zpráv k obrázkům",
        "short_instruction": "Přiřaďte obrázky k textovým informacím A-H. 3 informace nepotřebujete.",
        "learner_instruction": "Ghép 5 hình ảnh với thông tin A-H. Có 3 thông tin dư.",
        "estimated_duration_sec": 1200,
        "sample_answer_enabled": False,
        "status": "published", "pool": pool,
        **({"skill_id": skill_id, "module_id": module_id} if skill_id else {}),
        "detail": {
            "items": [
                {"item_no": 1, "text": "KADEŘNICTVÍ — Mohu vás ostříhat zítra v 10:00"},
                {"item_no": 2, "text": "Vaše objednávka je připravena k vyzvednutí"},
                {"item_no": 3, "text": "Autoservis Vexa — vaše auto je připravené"},
                {"item_no": 4, "text": "Balík si můžete vyzvednout u přepážky 3"},
                {"item_no": 5, "text": "Máte zájem o ten sporák? Kuchyně Lima"}
            ],
            "options": [
                {"key": "A", "text": "Celodenní parkování zdarma. Město Brno."},
                {"key": "B", "text": "Vaše pračka je opravená. Zavolejte."},
                {"key": "C", "text": "Vaše auto je připravené. Autoservis Vexa."},
                {"key": "D", "text": "Balík si můžete vyzvednout u přepážky 3."},
                {"key": "E", "text": "Objednávka číslo 1234 je připravena k vyzvednutí."},
                {"key": "F", "text": "Máte zájem o ten sporák? Kuchyně Lima."},
                {"key": "G", "text": "Rezervace na jméno Novák potvrzena."},
                {"key": "H", "text": "Můžu vás ostříhat dnes v 16:00. J. Novotná."}
            ],
            "correct_answers": {"1": "H", "2": "E", "3": "C", "4": "D", "5": "F"}
        }
    }

def ex_cteni2(pool, skill_id=None, module_id=None):
    return {
        "exercise_type": "cteni_2",
        "title": "Čtení 2 — Otevření sportoviště",
        "short_instruction": "Přečtěte si text a vyberte správnou odpověď A-D.",
        "learner_instruction": "Đọc văn bản và chọn đáp án A-D cho câu 6-10.",
        "estimated_duration_sec": 1200,
        "sample_answer_enabled": False,
        "status": "published", "pool": pool,
        **({"skill_id": skill_id, "module_id": module_id} if skill_id else {}),
        "detail": {
            "text": "Vážení spoluobčané,\n\nvšechny Vás zveme na slavnostní otevření nového sportoviště, které se koná dne 25. 6. Sportoviště nabízí tenisové kurty, basketbalové hřiště, dětské hřiště a malý bufet. V červenci bude sportoviště otevřeno každý den od 8 do 20 hodin. Vstup pro děti do 12 let je zdarma. Pro dospělé stojí vstup 50 korun za celý den. V srpnu bude sportoviště kvůli rekonstrukci zavřeno. Od září opět otevřeno. Těšíme se na vaši návštěvu!\n\nSpráva města",
            "questions": [
                {"question_no": 6, "prompt": "Kdy se otevírá nové sportoviště?", "options": [{"key": "A", "text": "24. 6."}, {"key": "B", "text": "25. 6."}, {"key": "C", "text": "26. 6."}, {"key": "D", "text": "27. 6."}]},
                {"question_no": 7, "prompt": "Co není na novém sportovišti?", "options": [{"key": "A", "text": "Tenisové kurty"}, {"key": "B", "text": "Bazén"}, {"key": "C", "text": "Basketbalové hřiště"}, {"key": "D", "text": "Bufet"}]},
                {"question_no": 8, "prompt": "Kolik zaplatí dospělý za celý den?", "options": [{"key": "A", "text": "Zdarma"}, {"key": "B", "text": "30 Kč"}, {"key": "C", "text": "50 Kč"}, {"key": "D", "text": "100 Kč"}]},
                {"question_no": 9, "prompt": "Ve kterém měsíci bude sportoviště zavřeno?", "options": [{"key": "A", "text": "V červnu"}, {"key": "B", "text": "V červenci"}, {"key": "C", "text": "V srpnu"}, {"key": "D", "text": "V září"}]},
                {"question_no": 10, "prompt": "Kdy mají děti do 12 let vstup zdarma?", "options": [{"key": "A", "text": "Jen v červenci"}, {"key": "B", "text": "Vždy"}, {"key": "C", "text": "O víkendech"}, {"key": "D", "text": "Nikdy"}]}
            ],
            "correct_answers": {"6": "B", "7": "B", "8": "C", "9": "C", "10": "B"}
        }
    }

def ex_cteni3(pool, skill_id=None, module_id=None):
    return {
        "exercise_type": "cteni_3",
        "title": "Čtení 3 — Kurzy (přiřazení textů k osobám)",
        "short_instruction": "Přiřaďte texty 11-14 k vhodné osobě A-E. Jednu osobu nepotřebujete.",
        "learner_instruction": "Ghép 4 đoạn văn (11-14) với nhân vật phù hợp A-E. Có 1 nhân vật thừa.",
        "estimated_duration_sec": 1200,
        "sample_answer_enabled": False,
        "status": "published", "pool": pool,
        **({"skill_id": skill_id, "module_id": module_id} if skill_id else {}),
        "detail": {
            "texts": [
                {"item_no": 11, "text": "Zajímá vás práce programátora? Chcete se zlepšit v práci s počítačem a v programování? Je tady kurz pro pokročilé informatiky, kteří hledají práci."},
                {"item_no": 12, "text": "Jazyková škola Sprich v centru Brna nabízí kurzy německého jazyka pro mírně a středně pokročilé. Možnost získat certifikát. Ceny jsou od 4 600 Kč za kurz."},
                {"item_no": 13, "text": "Nevíte, kde hledat práci? V našem společenském centru vám poradíme. Naučíte se znát trh práce a připravit si životopis a motivační dopis."},
                {"item_no": 14, "text": "Nabízíme kurz vaření pro začátečníky. Naučíte se připravit tradiční česká jídla. Kurz probíhá každou sobotu od 10 do 14 hodin."}
            ],
            "persons": [
                {"key": "A", "name": "Jana", "description": "Chce se naučit vařit česká jídla."},
                {"key": "B", "name": "Pavel", "description": "Umí trochu německy a chce to zlepšit."},
                {"key": "C", "name": "Marta", "description": "Je zkušená programátorka a hledá práci v IT."},
                {"key": "D", "name": "Lucie", "description": "Přišla do ČR a neví, jak hledat práci."},
                {"key": "E", "name": "Tomáš", "description": "Chce základy práce s počítačem pro seniory."}
            ],
            "correct_answers": {"11": "C", "12": "B", "13": "D", "14": "A"}
        }
    }

def ex_cteni4(pool, skill_id=None, module_id=None):
    return {
        "exercise_type": "cteni_4",
        "title": "Čtení 4 — Různé texty (výběr A-D)",
        "short_instruction": "Přečtěte si texty 15-20 a vyberte správnou odpověď A-D.",
        "learner_instruction": "Đọc và trả lời câu 15-20, chọn A-D.",
        "estimated_duration_sec": 1200,
        "sample_answer_enabled": False,
        "status": "published", "pool": pool,
        **({"skill_id": skill_id, "module_id": module_id} if skill_id else {}),
        "detail": {
            "context": "Přečtěte si různé krátké texty a odpovězte na otázky.",
            "questions": [
                {"question_no": 15, "prompt": "Text: Muzeum bude v pátek otevřeno do půlnoci. Jak dlouho bude muzeum otevřeno v pátek?", "options": [{"key": "A", "text": "Do 18:00"}, {"key": "B", "text": "Do 20:00"}, {"key": "C", "text": "Do 22:00"}, {"key": "D", "text": "Do 24:00"}]},
                {"question_no": 16, "prompt": "Text: Pronajmu byt 2+kk, 55 m², Praha 6, metro 5 minut, 18 000 Kč/měs. Co nabízí inzerát?", "options": [{"key": "A", "text": "Byt k prodeji"}, {"key": "B", "text": "Byt k pronájmu"}, {"key": "C", "text": "Dům k pronájmu"}, {"key": "D", "text": "Garáž k pronájmu"}]},
                {"question_no": 17, "prompt": "Text: Dnes je v restauraci polévka zdarma ke každému hlavnímu jídlu. Co dostanete zdarma?", "options": [{"key": "A", "text": "Dezert"}, {"key": "B", "text": "Nápoj"}, {"key": "C", "text": "Polévku"}, {"key": "D", "text": "Salát"}]},
                {"question_no": 18, "prompt": "Text: Výstava fotografií bude v galerii od 1. do 31. května. Jak dlouho trvá výstava?", "options": [{"key": "A", "text": "Jeden týden"}, {"key": "B", "text": "Dva týdny"}, {"key": "C", "text": "Tři týdny"}, {"key": "D", "text": "Celý měsíc"}]},
                {"question_no": 19, "prompt": "Text: Kvůli opravě bude zastávka Náměstí uzavřena. Přesun na zastávku Parková, 200 m. Co je uzavřeno?", "options": [{"key": "A", "text": "Náměstí"}, {"key": "B", "text": "Park"}, {"key": "C", "text": "Zastávka"}, {"key": "D", "text": "Ulice"}]},
                {"question_no": 20, "prompt": "Text: Zápis do školy je v pátek od 14 do 18 hodin v ředitelně. Kdy je zápis?", "options": [{"key": "A", "text": "Ve čtvrtek"}, {"key": "B", "text": "V pátek"}, {"key": "C", "text": "V sobotu"}, {"key": "D", "text": "V pondělí"}]}
            ],
            "correct_answers": {"15": "D", "16": "B", "17": "C", "18": "D", "19": "C", "20": "B"}
        }
    }

def ex_cteni5(pool, skill_id=None, module_id=None):
    return {
        "exercise_type": "cteni_5",
        "title": "Čtení 5 — Bramborový salát z Pohořelic",
        "short_instruction": "Přečtěte si text a doplňte správnou informaci k úkolům 21-25.",
        "learner_instruction": "Đọc văn bản và điền thông tin đúng vào ô 21-25.",
        "estimated_duration_sec": 1200,
        "sample_answer_enabled": False,
        "status": "published", "pool": pool,
        **({"skill_id": skill_id, "module_id": module_id} if skill_id else {}),
        "detail": {
            "text": "Bramborový salát z Pohořelic:\n\nDnes vám nabízíme recept na jednoduchý a chutný bramborový salát, který nám poslala naše čtenářka Jarmila Kučerová z Pohořelic.\n\nPotřebujeme: 1 kg brambor, jednu velkou cibuli, dvě okurky, čtyři vajíčka, majonézu, hořčici, sůl a pepř. Pozor — nepoužívejte olivový olej, salát by byl příliš mastný.\n\nPostup: Brambory uvařte celé den před přípravou salátu a nechte je vychladnout. Nakrájejte brambory, okurky a uvařená vajíčka. Nakrájenou cibuli přidejte k ostatním surovinám. Vše dobře promícháme a servírujeme, nejlépe s řízkem nebo rybou.",
            "questions": [
                {"question_no": 21, "prompt": "Podle receptu můžeme připravit..."},
                {"question_no": 22, "prompt": "Na salát potřebujeme jednu..."},
                {"question_no": 23, "prompt": "Na salát není vhodné použít olivový..."},
                {"question_no": 24, "prompt": "Brambory uvaříme 1 ... před přípravou salátu."},
                {"question_no": 25, "prompt": "K salátu se nejlépe hodí řízek nebo..."}
            ],
            "correct_answers": {
                "21": "bramborový salát",
                "22": "velkou cibuli",
                "23": "olej",
                "24": "den",
                "25": "ryba"
            }
        }
    }

# ──────────────────────────────────────────────────────────────────────────────
def main():
    print("=" * 60)
    print("Seed: Modelový test A2 druhy (NPI ČR, platný od dubna 2026)")
    print("=" * 60)

    token = login()

    # ── 1. COURSE ─────────────────────────────────────────────────────────────
    print("\n[1] Course")
    course = create_course(token,
        title="Ôn thi A2 Trvalý pobyt — Modelový test 2",
        slug="a2-trvalypobyt-modelovy-test-2",
        description="Luyện thi A2 Trvalý pobyt theo đề thi mẫu số 2 (NPI ČR, format mới tháng 4/2026).")
    if not course:
        sys.exit("Cannot create course")
    cid = course["id"]

    # ── 2. MODULES + SKILLS + EXERCISES (pool=course) ─────────────────────────
    print("\n[2] Modules, Skills, Exercises (pool=course)")

    skill_ids = {}

    # --- Mluvení ---
    m_noi = create_module(token, cid, "mluvenig", "Mluvení — Nói", "Luyện kỹ năng nói: Úloha 1-4", 1)
    if m_noi:
        s_noi = create_skill(token, m_noi["id"], "noi", "Nói (Mluvení)", 1)
        if s_noi:
            skill_ids["noi"] = s_noi["id"]
            for ex_fn in [ex_uloha1, ex_uloha2, ex_uloha3, ex_uloha4]:
                ex = ex_fn("course", s_noi["id"], m_noi["id"])
                create_exercise(token, ex)

    # --- Psaní ---
    m_viet = create_module(token, cid, "psani", "Psaní — Viết", "Luyện kỹ năng viết: Psaní 1-2", 2)
    if m_viet:
        s_viet = create_skill(token, m_viet["id"], "viet", "Viết (Psaní)", 1)
        if s_viet:
            skill_ids["viet"] = s_viet["id"]
            for ex_fn in [ex_psani1, ex_psani2]:
                ex = ex_fn("course", s_viet["id"], m_viet["id"])
                create_exercise(token, ex)

    # --- Poslech ---
    m_nghe = create_module(token, cid, "poslech", "Poslech — Nghe", "Luyện kỹ năng nghe: Poslech 1-5", 3)
    if m_nghe:
        s_nghe = create_skill(token, m_nghe["id"], "nghe", "Nghe (Poslech)", 1)
        if s_nghe:
            skill_ids["nghe"] = s_nghe["id"]
            for ex_fn in [ex_poslech1, ex_poslech2, ex_poslech3, ex_poslech4, ex_poslech5]:
                ex = ex_fn("course", s_nghe["id"], m_nghe["id"])
                create_exercise(token, ex)

    # --- Čtení ---
    m_doc = create_module(token, cid, "cteni", "Čtení — Đọc", "Luyện kỹ năng đọc: Čtení 1-5", 4)
    if m_doc:
        s_doc = create_skill(token, m_doc["id"], "doc", "Đọc (Čtení)", 1)
        if s_doc:
            skill_ids["doc"] = s_doc["id"]
            for ex_fn in [ex_cteni1, ex_cteni2, ex_cteni3, ex_cteni4, ex_cteni5]:
                ex = ex_fn("course", s_doc["id"], m_doc["id"])
                create_exercise(token, ex)

    # ── 3. EXERCISES (pool=exam) for MockTest sections ────────────────────────
    print("\n[3] Exercises (pool=exam) for MockTest sections")
    exam_ids = {}

    exam_defs = [
        ("uloha_1", ex_uloha1), ("uloha_2", ex_uloha2),
        ("uloha_3", ex_uloha3), ("uloha_4", ex_uloha4),
        ("psani_1", ex_psani1), ("psani_2", ex_psani2),
        ("poslech_1", ex_poslech1), ("poslech_2", ex_poslech2),
        ("poslech_3", ex_poslech3), ("poslech_4", ex_poslech4),
        ("poslech_5", ex_poslech5),
        ("cteni_1", ex_cteni1), ("cteni_2", ex_cteni2),
        ("cteni_3", ex_cteni3), ("cteni_4", ex_cteni4),
        ("cteni_5", ex_cteni5),
    ]
    for key, ex_fn in exam_defs:
        ex = ex_fn("exam")
        r = create_exercise(token, ex)
        if r:
            exam_ids[key] = r["id"]

    # ── 4. MOCK TESTS ──────────────────────────────────────────────────────────
    print("\n[4] MockTests")

    # --- Speaking mock test ---
    if all(k in exam_ids for k in ["uloha_1", "uloha_2", "uloha_3", "uloha_4"]):
        create_mock_test(token,
            title="Modelový test 2 — Mluvení (Ústní část)",
            description="Phần thi nói A2: Úloha 1-4. Tổng 40 điểm. Đậu ≥24 điểm (60%).",
            duration=15, status="published", session_type="speaking",
            sections=[
                {"sequence_no": 1, "exercise_id": exam_ids["uloha_1"], "exercise_type": "uloha_1_topic_answers", "max_points": 8},
                {"sequence_no": 2, "exercise_id": exam_ids["uloha_2"], "exercise_type": "uloha_2_dialogue_questions", "max_points": 12},
                {"sequence_no": 3, "exercise_id": exam_ids["uloha_3"], "exercise_type": "uloha_3_story_narration", "max_points": 10},
                {"sequence_no": 4, "exercise_id": exam_ids["uloha_4"], "exercise_type": "uloha_4_choice_reasoning", "max_points": 7},
            ]
        )

    # --- Písemná mock test (Čtení + Psaní + Poslech) ---
    pisemna_keys = ["cteni_1","cteni_2","cteni_3","cteni_4","cteni_5",
                    "psani_1","psani_2",
                    "poslech_1","poslech_2","poslech_3","poslech_4","poslech_5"]
    if all(k in exam_ids for k in pisemna_keys):
        create_mock_test(token,
            title="Modelový test 2 — Písemná část",
            description="Phần thi viết A2: Čtení (25đ) + Psaní (20đ) + Poslech (25đ) = 70đ. Đậu ≥42 (60%).",
            duration=105, status="published", session_type="pisemna",
            sections=[
                {"sequence_no": 1,  "exercise_id": exam_ids["cteni_1"],   "exercise_type": "cteni_1",          "max_points": 5},
                {"sequence_no": 2,  "exercise_id": exam_ids["cteni_2"],   "exercise_type": "cteni_2",          "max_points": 5},
                {"sequence_no": 3,  "exercise_id": exam_ids["cteni_3"],   "exercise_type": "cteni_3",          "max_points": 4},
                {"sequence_no": 4,  "exercise_id": exam_ids["cteni_4"],   "exercise_type": "cteni_4",          "max_points": 6},
                {"sequence_no": 5,  "exercise_id": exam_ids["cteni_5"],   "exercise_type": "cteni_5",          "max_points": 5},
                {"sequence_no": 6,  "exercise_id": exam_ids["psani_1"],   "exercise_type": "psani_1_formular", "max_points": 8},
                {"sequence_no": 7,  "exercise_id": exam_ids["psani_2"],   "exercise_type": "psani_2_email",    "max_points": 12},
                {"sequence_no": 8,  "exercise_id": exam_ids["poslech_1"], "exercise_type": "poslech_1",        "max_points": 5},
                {"sequence_no": 9,  "exercise_id": exam_ids["poslech_2"], "exercise_type": "poslech_2",        "max_points": 5},
                {"sequence_no": 10, "exercise_id": exam_ids["poslech_3"], "exercise_type": "poslech_3",        "max_points": 5},
                {"sequence_no": 11, "exercise_id": exam_ids["poslech_4"], "exercise_type": "poslech_4",        "max_points": 5},
                {"sequence_no": 12, "exercise_id": exam_ids["poslech_5"], "exercise_type": "poslech_5",        "max_points": 5},
            ]
        )

    print("\n" + "=" * 60)
    print("✓ Seed complete!")
    print("  → CMS: http://localhost:3000/courses")
    print("  → CMS: http://localhost:3000/mock-tests")
    print("=" * 60)

if __name__ == "__main__":
    main()
