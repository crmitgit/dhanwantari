import { LightningElement, api } from 'lwc';
import getReferralValidation from '@salesforce/apex/ReferralValidationService.getReferralValidation';
import getValidationStatus from '@salesforce/apex/ReferralValidationService.getValidationStatus';
import rerunValidation from '@salesforce/apex/ReferralValidationService.rerunValidation';

const POLL_MS = 5000;
const MAX_POLLS = 40; // a little over three minutes
const NOT_RECORDED = 'Not recorded';

const LEVELS = ['High', 'Medium', 'Low'];

const STATUS_CLASS = { green: 'g', amber: 'a', red: 'r' };

function statusClass(status) {
    return STATUS_CLASS[(status || '').toLowerCase()] || 'plain';
}

function errorMessage(error) {
    if (error && error.body && error.body.message) return error.body.message;
    if (error && error.message) return error.message;
    return 'Something went wrong. / कुछ गलत हो गया।';
}

function pair(k, v, flag) {
    const blank = v === null || v === undefined || v === '';
    return {
        k,
        v: blank ? NOT_RECORDED : v,
        cls: blank ? 'v muted' : flag ? `v flag-${flag}` : 'v'
    };
}

function byRef(list) {
    const map = {};
    (list || []).forEach((item) => {
        if (item && item.ref) map[item.ref] = item;
    });
    return map;
}

function pts(value) {
    return value === null || value === undefined ? '0' : `${Number(value)}`;
}

function join(...parts) {
    return parts.filter((p) => p !== null && p !== undefined && p !== '').join(', ');
}

export default class ReferralValidationPanel extends LightningElement {
    @api referralName;
    @api hospitalName;

    facts;
    validation = {};
    isLoading = true;
    isRerunning = false;
    timedOut = false;
    activeTab = 'referral';
    pollCount = 0;
    pollTimer;

    _onKeydown = (event) => {
        if (event.key === 'Escape') this.handleClose();
    };

    connectedCallback() {
        window.addEventListener('keydown', this._onKeydown);
        this.load();
    }

    disconnectedCallback() {
        window.removeEventListener('keydown', this._onKeydown);
        clearTimeout(this.pollTimer);
    }

    // ---------------- data ----------------

    get params() {
        return { referralName: this.referralName, hospitalName: this.hospitalName };
    }

    async load() {
        this.isLoading = true;
        try {
            const result = await getReferralValidation(this.params);
            this.facts = result;
            this.applyValidation(result.validation);
        } catch (error) {
            this.dispatchEvent(new CustomEvent('validationerror', { detail: { message: errorMessage(error) } }));
        } finally {
            this.isLoading = false;
        }
    }

    applyValidation(state) {
        this.validation = state || {};
        clearTimeout(this.pollTimer);
        if (this.validation.status === 'Pending') {
            if (this.pollCount < MAX_POLLS) {
                // eslint-disable-next-line @lwc/lwc/no-async-operation
                this.pollTimer = setTimeout(() => this.poll(), POLL_MS);
            } else {
                this.timedOut = true;
            }
        }
    }

    async poll() {
        this.pollCount += 1;
        try {
            this.applyValidation(await getValidationStatus(this.params));
        } catch (error) {
            this.validation = { status: 'Failed', error: errorMessage(error) };
        }
    }

    async handleRerun() {
        this.isRerunning = true;
        this.pollCount = 0;
        this.timedOut = false;
        try {
            this.applyValidation(await rerunValidation(this.params));
        } catch (error) {
            this.validation = { status: 'Failed', error: errorMessage(error) };
        } finally {
            this.isRerunning = false;
        }
    }

    handleClose() {
        this.dispatchEvent(new CustomEvent('close'));
    }

    handleScrimClick(event) {
        if (event.target === event.currentTarget) this.handleClose();
    }

    handleTab(event) {
        this.activeTab = event.currentTarget.dataset.tab;
        const body = this.template.querySelector('.body');
        if (body) body.scrollTop = 0;
    }

    // ---------------- state ----------------

    get ai() {
        return this.validation && this.validation.ai ? this.validation.ai : null;
    }

    get hasFacts() {
        return !!this.facts;
    }

    get isPending() {
        return this.validation.status === 'Pending' && !this.timedOut;
    }

    get isFailed() {
        return this.validation.status === 'Failed' || (this.validation.status === 'Pending' && this.timedOut);
    }

    get failureText() {
        if (this.timedOut) return 'Checks are taking longer than usual. Try running them again.';
        return this.validation.error || 'The checks could not be completed.';
    }

    get rerunLabel() {
        return this.isRerunning ? 'Starting…' : 'Run checks again';
    }

    get rerunDisabled() {
        return this.isRerunning || this.isPending;
    }

    get referral() {
        return (this.facts && this.facts.referral) || {};
    }

    get patient() {
        return (this.facts && this.facts.patient) || {};
    }

    // ---------------- rail ----------------

    get score() {
        return (this.facts && this.facts.score) || {};
    }

    get confidence() {
        return this.score.band;
    }

    get verdictClass() {
        return `word ${(this.confidence || '').toLowerCase()}`;
    }

    get scoreLine() {
        const s = this.score;
        return `${s.score} / 100 · ${pts(s.points)} of ${pts(s.maxPoints)} points`;
    }

    get capLines() {
        return (this.score.caps || []).map((text, i) => ({ key: `cap${i}`, text }));
    }

    get hasCaps() {
        return this.capLines.length > 0;
    }

    get capHeading() {
        return this.score.capped
            ? `Points alone give ${this.score.rawBand}. Capped at ${this.score.band}:`
            : 'Caps checked, none lowered the level:';
    }

    get verdictSummary() {
        if (this.ai && this.ai.summary) return this.ai.summary;
        if (this.isPending) return 'Level and score are calculated from the record. The written explanation is being prepared.';
        return '';
    }

    get scale() {
        const s = this.score;
        const tails = {
            High: `${s.bandHighMin}+ points`,
            Medium: `${s.bandMediumMin}–${s.bandHighMin - 1} points`,
            Low: `below ${s.bandMediumMin}`
        };
        return LEVELS.map((key) => ({
            key,
            tail: tails[key],
            cls: key === this.confidence ? `lv on ${key.toLowerCase()}` : 'lv'
        }));
    }

    get dimensions() {
        return (this.score.areas || []).map((a) => ({
            key: a.key,
            label: a.label,
            value: `${pts(a.points)} / ${pts(a.maxPoints)}`,
            sq: `sq ${statusClass(a.status)}`
        }));
    }

    get scoreAreas() {
        return (this.score.areas || []).map((a) => ({
            ...a,
            total: `${pts(a.points)} / ${pts(a.maxPoints)}`,
            keyCls: `key ${statusClass(a.status)}`,
            sq: `sq ${statusClass(a.status)}`,
            rows: (a.items || []).map((it, i) => ({
                key: `${a.key}-${i}`,
                label: it.label,
                detail: it.detail,
                value: `${pts(it.points)} / ${pts(it.maxPoints)}`,
                cls: it.met ? 'item met' : Number(it.points) > 0 ? 'item part' : 'item miss',
                mark: it.met ? '✓' : Number(it.points) > 0 ? '◐' : '✕'
            }))
        }));
    }

    get pointsLost() {
        let lost = 0;
        (this.score.areas || []).forEach((a) => (a.items || []).forEach((it) => {
            if (!it.met) lost += 1;
        }));
        return lost;
    }

    get fit() {
        return (this.facts && this.facts.fit) || {};
    }

    get fitRows() {
        const f = this.fit;
        const rows = (f.specialties || []).map((s) => ({
            key: `sp-${s.label}`,
            label: s.label,
            value: s.status === 'offered' ? 'Offered' : s.status === 'not_offered' ? 'Not offered' : 'Unknown',
            detail: s.detail,
            sq: `sq ${s.status === 'offered' ? 'g' : s.status === 'not_offered' ? 'r' : 'plain'}`
        }));
        if (!f.hasSpecialtyRequest) {
            rows.push({ key: 'sp-none', label: 'Specialty requested', value: 'Not recorded', detail: '', sq: 'sq plain' });
        }
        rows.push({
            key: 'prev',
            label: 'Received here before',
            value: f.previouslyReceived ? 'Yes' : 'No',
            detail: f.previousDetail,
            sq: 'sq plain'
        });
        return rows;
    }

    get fitPairs() {
        const f = this.fit;
        return [
            ...this.fitRows.map((r) => pair(r.label, `${r.value}. ${r.detail || ''}`.trim())),
            pair(`Specialties recorded for ${f.hospital || 'this hospital'}`, f.offeredList)
        ];
    }

    get flagRows() {
        return ((this.facts && this.facts.flags) || []).map((f, i) => {
            const cls = statusClass(f.severity);
            return {
                ...f,
                key: `flag${i}`,
                label: f.severity === 'red' ? 'Verify first' : 'Check',
                keyCls: `key ${cls}`,
                sq: `sq ${cls}`
            };
        });
    }

    get hasFlags() {
        return this.flagRows.length > 0;
    }

    get flagSummary() {
        const n = this.flagRows.length;
        return n === 0 ? 'None found' : `${n} item${n === 1 ? '' : 's'}`;
    }

    get clinicalNote() {
        const n = this.ai && this.ai.clinicalNote;
        if (!n || !n.text) return null;
        return { ...n, keyCls: `key ${statusClass(n.status)}`, sq: `sq ${statusClass(n.status)}` };
    }

    get caseFacts() {
        const r = this.referral;
        const p = this.patient;
        const visits = this.visitCount;
        return [
            pair('Patient', join(p.name, p.age, p.gender && p.gender.toLowerCase())),
            pair('Referred by', join(r.doctor, r.facility)),
            pair('Requested', join(r.specialty, r.priority && `${r.priority.toLowerCase()} priority`)),
            pair('Referral date', r.dateLabel),
            pair('Under care since', r.underCareSince ? `${r.underCareSince}, ${visits} ${visits === 1 ? 'visit' : 'visits'}` : null)
        ];
    }

    get runLine() {
        if (this.isPending) return 'Checks running now';
        return this.validation.runAt ? `Checks last run ${this.validation.runAt}` : '';
    }

    // ---------------- header ----------------

    get headerLine() {
        const r = this.referral;
        const where = r.receivedDate ? `Patient received on ${r.receivedDate}.` : 'Patient not yet received.';
        return `${where} Referral ${r.name}${r.priority ? `, ${r.priority.toLowerCase()} priority` : ''}.`;
    }

    get liveLabel() {
        if (this.isPending) return 'Running checks';
        if (this.isFailed) return 'Checks incomplete';
        return 'Awaiting your decision';
    }

    get liveClass() {
        if (this.isFailed) return 'live r';
        if (this.isPending) return 'live plain';
        return 'live';
    }

    // ---------------- tabs ----------------

    get visitCount() {
        return (this.facts && this.facts.visits && this.facts.visits.length) || 0;
    }

    get tabs() {
        const count = (list) => (this.ai && list ? list.length : null);
        const defs = [
            { id: 'referral', label: 'Referral', cnt: null },
            { id: 'visits', label: 'Visits', cnt: this.visitCount },
            { id: 'checks', label: 'Score', cnt: this.pointsLost },
            { id: 'evidence', label: 'Evidence', cnt: this.evidenceRows.length },
            { id: 'requests', label: 'Requests', cnt: this.requestRows.length },
            { id: 'actions', label: 'What to do', cnt: count(this.ai && this.ai.actions) }
        ];
        return defs.map((t) => ({
            ...t,
            hasCnt: t.cnt !== null && t.cnt !== undefined,
            cls: t.id === this.activeTab ? 'tab active' : 'tab',
            selected: t.id === this.activeTab ? 'true' : 'false'
        }));
    }

    get showReferral() { return this.activeTab === 'referral'; }
    get showVisits() { return this.activeTab === 'visits'; }
    get showChecks() { return this.activeTab === 'checks'; }
    get showEvidence() { return this.activeTab === 'evidence'; }
    get showRequests() { return this.activeTab === 'requests'; }
    get showActions() { return this.activeTab === 'actions'; }

    // ---------------- referral tab ----------------

    get referralLede() {
        return (this.ai && this.ai.referralLede) || this.referral.reason || this.referral.complaints;
    }

    get patientUnder() {
        const p = this.patient;
        const bits = [p.gender, p.age && `${p.age}`, p.birthDate && `born ${p.birthDate}`].filter(Boolean);
        return bits.length ? `${bits.join(', ')}.` : '';
    }

    get patientPairs() {
        const p = this.patient;
        return [
            pair('PM-JAY ID', p.pmjayId),
            pair('Contact', p.phone),
            pair('PM-JAY beneficiary', p.pmjayVerified ? 'Verified' : 'Not verified', p.pmjayVerified ? 'g' : 'a'),
            pair('Blood group', p.bloodGroup),
            pair('Known allergies', p.allergies),
            pair('Recorded conditions', p.conditions)
        ];
    }

    get facilityUnder() {
        const r = this.referral;
        return join(r.facility, r.doctor && `Dr. ${r.doctor.replace(/^Dr\.?\s*/i, '')}`);
    }

    get facilityPairs() {
        const r = this.referral;
        return [
            pair('Referral priority', r.priority),
            pair('Specialty asked for', r.specialty),
            pair('Visits before referring', this.visitCount ? `${this.visitCount}` : null),
            pair('Recommended visit by', r.recommendedVisitBy),
            pair('Consent', r.consent === 'Granted' ? `Granted${r.consentDate ? `, ${r.consentDate}` : ''}` : r.consent, 'g')
        ];
    }

    get picturePairs() {
        const c = (this.ai && this.ai.clinicalPicture) || {};
        const r = this.referral;
        return [
            pair('Chief complaints', r.complaints),
            pair('Working diagnosis', c.workingDiagnosis || r.diagnosis),
            pair('Alongside it', c.alongside),
            pair('Risk factors', c.riskFactors),
            pair('On treatment', c.onTreatment || (this.facts && this.facts.currentMedications)),
            pair('Safety netting', c.safetyNetting)
        ];
    }

    get otherReferrals() {
        return ((this.facts && this.facts.otherReferrals) || []).map((o) => ({
            ...o,
            line: join(o.dateLabel, o.referredTo, o.priority, o.received ? 'received' : 'not received')
        }));
    }

    get hasOtherReferrals() {
        return this.otherReferrals.length > 0;
    }

    // ---------------- visits tab ----------------

    get visitsLede() {
        if (this.ai && this.ai.visitsLede) return this.ai.visitsLede;
        return this.visitCount
            ? `${this.visitCount} consultation${this.visitCount === 1 ? '' : 's'} recorded at the PHWC before this referral.`
            : 'No consultations were recorded at the PHWC before this referral.';
    }

    get visitRows() {
        const headlines = byRef(this.ai && this.ai.visits);
        const visits = (this.facts && this.facts.visits) || [];
        return visits.map((v, i) => {
            const h = headlines[v.ref];
            let label = i === 0 ? 'First visit' : `Visit ${i + 1}`;
            if (v.isReferralVisit) label = 'Referral raised';
            return {
                ...v,
                label,
                headline: (h && h.headline) || v.complaints || v.name,
                showComplaints: !!(h && h.headline && v.complaints),
                rowCls: v.isReferralVisit ? 'now' : '',
                bpText: v.bp || '—',
                pulseText: v.pulse || '—',
                spo2Text: v.spo2 || '—',
                tempText: v.temp || '—',
                weightText: v.weight || '—',
                hasPlan: !!v.plan,
                hasMeds: !!v.medications
            };
        });
    }

    get hasVisits() {
        return this.visitCount > 0;
    }

    // ---------------- checks tab ----------------

    get checksLede() {
        const s = this.score;
        return `${s.band} record strength, ${s.score} out of 100. This rates how well the PHWC record supports the referral, not whether to accept the patient. Each data point below is read from the record and carries a fixed weight. ${this.pointsLost} of them did not earn full points.`;
    }

    get hasAiChecks() {
        return this.checkRows.length > 0 || !!this.clinicalNote;
    }

    get checkRows() {
        return ((this.ai && this.ai.checks) || []).map((c, i) => ({
            ...c,
            key: `c${i}`,
            keyCls: `key ${statusClass(c.status)}`,
            sq: `sq ${statusClass(c.status)}`,
            hasAside: !!c.aside
        }));
    }

    // ---------------- evidence tab ----------------

    get evidenceRows() {
        const judged = byRef(this.ai && this.ai.evidence);
        const docs = ((this.facts && this.facts.documents) || []).map((d) => ({
            ref: d.ref, title: d.title, right: join(d.source, d.dateLabel)
        }));
        const diags = ((this.facts && this.facts.diagnostics) || []).map((d) => ({
            ref: d.ref, title: d.title, right: join(d.status, d.dateLabel)
        }));
        return [...docs, ...diags].map((row) => {
            const j = judged[row.ref];
            const cls = j ? statusClass(j.status) : 'plain';
            return {
                ...row,
                label: j ? j.label : this.ai ? 'Not assessed' : 'Checking',
                note: j && j.note,
                keyCls: `key ${cls}`,
                sq: `sq ${cls}`
            };
        });
    }

    get evidenceLede() {
        if (this.ai && this.ai.evidenceLede) return this.ai.evidenceLede;
        return 'Documents and diagnostic results shared with this referral.';
    }

    get hasEvidence() {
        return this.evidenceRows.length > 0;
    }

    get diagnosticRows() {
        return ((this.facts && this.facts.diagnostics) || []).map((d) => ({
            ...d,
            resultText: d.result || 'No result recorded',
            resultCls: d.result ? '' : 'fine'
        }));
    }

    get hasDiagnostics() {
        return this.diagnosticRows.length > 0;
    }

    get documentChecks() {
        return ((this.ai && this.ai.documentChecks) || []).map((c, i) => ({
            ...c,
            key: `d${i}`,
            keyCls: `key ${statusClass(c.status)}`,
            sq: `sq ${statusClass(c.status)}`
        }));
    }

    get hasDocumentChecks() {
        return this.documentChecks.length > 0;
    }

    // ---------------- requests tab ----------------

    get requestsLede() {
        if (this.ai && this.ai.requestsLede) return this.ai.requestsLede;
        return 'Services requested with this referral and investigations ordered at the PHWC.';
    }

    get requestRows() {
        const judged = byRef(this.ai && this.ai.requests);
        return ((this.facts && this.facts.requests) || []).map((r) => {
            const j = judged[r.ref];
            const cls = j ? statusClass(j.status) : 'plain';
            return {
                ...r,
                label: j ? j.label : this.ai ? 'Not assessed' : 'Checking',
                note: (j && j.note) || r.detail,
                keyCls: `key ${cls}`,
                sq: `sq ${cls}`
            };
        });
    }

    get hasRequests() {
        return this.requestRows.length > 0;
    }

    get requestsCallout() {
        return this.ai && this.ai.requestsCallout;
    }

    // ---------------- actions tab ----------------

    get actionsLede() {
        return this.ai && this.ai.actionsLede;
    }

    get actionRows() {
        return ((this.ai && this.ai.actions) || []).map((a, i) => ({ ...a, key: `a${i}` }));
    }
}