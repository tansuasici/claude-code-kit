# Task Board

## In Progress

---

## Up Next

---

## Done

### Task 1: Profiller (`--profile minimal|standard|strict`)

**Goal**: install.sh'e profil desteği eklemek. Kullanıcı ihtiyacına göre farklı seviyelerde kurulum.

**Profil tanımları:**

| Profil | CLAUDE.md | agent_docs/ | tasks/ | hooks | settings.json |
|--------|-----------|-------------|--------|-------|----------------|
| **minimal** | Hayır | Hayır | Hayır | Seçilen hook'lar | Sadece hook config |
| **standard** | Evet | Evet | Evet | Default 6 hook | Tam config (şu anki) |
| **strict** | Evet | Evet | Evet | Tüm 9 hook (auto-lint, auto-format dahil) | Tam config |

**Yaklaşım:**
1. install.sh'e `--profile` flag'i ekle (default: standard)
2. Profil tanımlarını install.sh içinde fonksiyonlarla yönet
3. `minimal`: sadece `.claude/hooks/` + `settings.json` kopyalar (CLAUDE.md, agent_docs, tasks yok)
4. `standard`: mevcut davranış (değişiklik yok)
5. `strict`: standard + auto-lint + auto-format enabled in settings.json
6. README güncelle

**Files to Touch:**
- `install.sh` — profil mantığı
- `.claude/settings.strict.json` — strict profil settings (veya install.sh içinde generate)
- `README.md` — profil dokümantasyonu

---

### Task 2: Upgrade (`--upgrade`)

**Goal**: Mevcut kurulumu bozmadan yeni hook'ları/dosyaları ekleyen upgrade mekanizması.

**Yaklaşım:**
1. `--upgrade` flag'i ekle
2. Mantık: her dosya için — yoksa kopyala, varsa atla (mevcut davranış)
3. Hook'lar için: yeni hook dosyalarını ekle, mevcut hook'ları ezme
4. settings.json için: mevcut config'i koru, sadece yeni hook tanımlarını ekle (merge)
5. Upgrade sonunda diff/summary göster: "X yeni dosya eklendi, Y dosya atlandı"

**Files to Touch:**
- `install.sh` — upgrade mantığı + settings.json merge
- `README.md` — upgrade dokümantasyonu

---

### Task 3: Doctor (`doctor`)

**Goal**: Kurulum sağlığını doğrulayan bir komut.

**Kontroller:**
- [ ] Hook dosyaları executable mı?
- [ ] settings.json geçerli JSON mı?
- [ ] settings.json'daki hook path'leri gerçek dosyalara mı işaret ediyor?
- [ ] CODEBASE_MAP.md doldurulmuş mu? (placeholder kontrolü)
- [ ] Orphan hook'lar var mı? (dosya var ama settings.json'da yok)
- [ ] agent_docs/ dosyaları mevcut mu?

**Yaklaşım:**
1. install.sh'e `doctor` subcommand'ı ekle (veya ayrı `scripts/doctor.sh`)
2. Her kontrolü bir fonksiyon olarak yaz
3. Renkli çıktı: ✓ pass, ✗ fail, ! warn

**Files to Touch:**
- `scripts/doctor.sh` — yeni dosya
- `install.sh` — doctor'a referans / yönlendirme
- `README.md` — doctor dokümantasyonu

---

## Done

### Task: Agentic Engineering Best Practices — 7 Gap Fixes (2026-03-06)

**Goal**: Makale analizi sonucu tespit edilen 7 eksikliği gidermek.

**Changes made:**
1. `CLAUDE.md` — Added "After Compaction" rule + new agent_docs references
2. `agent_docs/contracts.md` — NEW: Task contract system with template & stop hook enforcement
3. `agent_docs/workflow.md` — Added "Separate Research from Implementation" + "Session Strategy"
4. `agent_docs/prompting.md` — NEW: Sycophancy awareness, neutral prompting, adversarial pattern
5. `agent_docs/subagents.md` — Added "Research-Then-Implement Pattern"
6. `agent_docs/skills.md` — Added "Periodic Cleanup" section with full checklist
7. `tasks/handoff.md` — Added handoff vs contract comparison
8. `CODEBASE_MAP.md` — Filled with real project data

---

## Not Now

