open util/ordering[Idx] as IdxOrder
open util/ordering[ParamIdx] as ParamIdxOrder

abstract sig Var {}

abstract sig Atom {}

abstract sig Sort {
	atoms : some Atom
}

abstract sig ParamIdx {}

// base name for an action
abstract sig BaseName {
	maxParam : ParamIdx
}

// concrete action
abstract sig Act {
	baseName : BaseName,
	params : ParamIdx->Atom
}


/* Formula signatures (represented by a DAG) */
abstract sig Formula {
	children : set Formula
}

sig TT, FF extends Formula {} {
	no children
}

sig Not extends Formula {
	child : Formula
} {
	children = child
}

sig Implies extends Formula {
	left : Formula,
	right : Formula
} {
	children = left + right
}

sig OnceVar extends Formula {
	baseName : BaseName,
	vars : ParamIdx->Var
} {
	no children
}

sig Forall extends Formula {
	var : Var,
	sort : Sort,
	matrix : Formula
} {
	children = matrix
}

sig Exists extends Formula {
	var : Var,
	sort : Sort,
	matrix : Formula
} {
	children = matrix
}

one sig Root extends Formula {} {
	one children
}

fact {
	all f : Formula | f in Root.*children // all formulas must be a sub-formula of the root
	no Root.^children & Root // root appears once
	all f : Formula | f not in f.^children // eliminates cycles in formula nodes
	ParamIdx.(OnceVar.vars) in (Forall.var + Exists.var) // approximately: no free variables
	all f : OnceVar | (f.vars).Var = rangeParamIdx[f.baseName.maxParam] // the number of params in each action-var must match the action
	all v1, v2 : Var, p : ParamIdx, f : OnceVar | (p->v1 in f.vars and p->v2 in f.vars) implies v1 = v2

	// do not quantify over a variable that's already in scope
	all f1, f2 : Forall | (f2 in f1.^children) implies not (f1.var = f2.var)
	all f1, f2 : Exists | (f2 in f1.^children) implies not (f1.var = f2.var)
	all f1 : Forall, f2 : Exists | (f2 in f1.^children) implies not (f1.var = f2.var)
	all f1 : Exists, f2 : Forall | (f2 in f1.^children) implies not (f1.var = f2.var)
}


abstract sig Env {
	maps : set(Var -> Atom)
}
one sig EmptyEnv extends Env {} {
	no maps
}

abstract sig Idx {}

abstract sig Trace {
	path : Idx -> Act, // the path for the trace
	lastIdx : Idx, // the last index in the path for the trace
	satisfies : Env -> Idx -> Formula // formulas that satisfy this trace
} {
	// trace semantics, i.e. e |- t,i |= f, where e is an environment, t is a trace, i is an index, and f is a formula
	all e : Env, i : Idx, f : TT | e->i->f in satisfies
	all e : Env, i : Idx, f : FF | e->i->f not in satisfies
	all e : Env, i : Idx, f : Not | e->i->f in satisfies iff (e->i->f.child not in satisfies)
	all e : Env, i : Idx, f : Implies | e->i->f in satisfies iff (e->i->f.left in satisfies implies e->i->f.right in satisfies)
	all e : Env, i : Idx, f : OnceVar | e->i->f in satisfies iff
		((some a : Act | concreteAct[a,e,f] and i->a in path) or (some i' : Idx | i'->i in next and e->i'->f in satisfies))
	all e : Env, i : Idx, f : Forall | e->i->f in satisfies iff
		(all x : f.sort.atoms | some e' : Env | pushEnv[e',e,f.var,x] and e'->i->f.matrix in satisfies)
	all e : Env, i : Idx, f : Exists | e->i->f in satisfies iff
		(some x : f.sort.atoms | some e' : Env | pushEnv[e',e,f.var,x] and e'->i->f.matrix in satisfies)
	all e : Env, i : Idx, f : Root | e->i->f in satisfies iff e->i->f.children in satisfies
}

pred concreteAct[a : Act, e : Env, f : OnceVar] {
	f.baseName = a.baseName and (~(f.vars)).(a.params) = e.maps
}

pred pushEnv[env', env : Env, v : Var, x : Atom] {
	env'.maps = env.maps + (v->x)
}

fun indices[t : Trace] : set Idx {
	t.lastIdx.*(~IdxOrder/next)
}

fun rangeParamIdx[p : ParamIdx] : set ParamIdx {
	p.*(~ParamIdxOrder/next)
}

abstract sig PosTrace extends Trace {} {}
abstract sig NegTrace extends Trace {} {}
one sig EmptyTrace extends Trace {} {
	 no path
}


/* main */
run {
	// find a formula that separates "good" traces from "bad" ones
	all pt : PosTrace | EmptyEnv->indices[pt]->Root in pt.satisfies
	all nt : NegTrace | no (EmptyEnv->nt.lastIdx->Root & nt.satisfies)
	EmptyEnv->T0->Root in EmptyTrace.satisfies // the formula must satisfy the empty trace
	minsome children // smallest formula possible
}
for 7 Formula

one sig P0, P1, P2, P3 extends ParamIdx {}

fact {
	ParamIdxOrder/first = P0
	ParamIdxOrder/next = P0->P1 + P1->P2 + P2->P3
}



one sig n1, n2, k1, k2, v1, v2 extends Atom {}

one sig Node extends Sort {} {
	atoms = n1 + n2
}
one sig Value extends Sort {} {
	atoms = v1 + v2
}
one sig Key extends Sort {} {
	atoms = k1 + k2
}

one sig RecvTransferMsg extends BaseName {} {
	maxParam = P2
}
one sig RecvTransferMsgn1k2v1 extends Act {} {
	baseName = RecvTransferMsg
	params = (P0->n1 + P1->k2 + P2->v1)
}
one sig RecvTransferMsgn1k2v2 extends Act {} {
	baseName = RecvTransferMsg
	params = (P0->n1 + P1->k2 + P2->v2)
}
one sig RecvTransferMsgn1k1v1 extends Act {} {
	baseName = RecvTransferMsg
	params = (P0->n1 + P1->k1 + P2->v1)
}
one sig RecvTransferMsgn2k2v1 extends Act {} {
	baseName = RecvTransferMsg
	params = (P0->n2 + P1->k2 + P2->v1)
}
one sig RecvTransferMsgn2k1v1 extends Act {} {
	baseName = RecvTransferMsg
	params = (P0->n2 + P1->k1 + P2->v1)
}
one sig RecvTransferMsgn1k1v2 extends Act {} {
	baseName = RecvTransferMsg
	params = (P0->n1 + P1->k1 + P2->v2)
}
one sig RecvTransferMsgn2k2v2 extends Act {} {
	baseName = RecvTransferMsg
	params = (P0->n2 + P1->k2 + P2->v2)
}
one sig RecvTransferMsgn2k1v2 extends Act {} {
	baseName = RecvTransferMsg
	params = (P0->n2 + P1->k1 + P2->v2)
}

one sig Reshard extends BaseName {} {
	maxParam = P3
}
one sig Reshardk2v1n2n1 extends Act {} {
	baseName = Reshard
	params = (P0->k2 + P1->v1 + P2->n2 + P3->n1)
}
one sig Reshardk2v1n2n2 extends Act {} {
	baseName = Reshard
	params = (P0->k2 + P1->v1 + P2->n2 + P3->n2)
}
one sig Reshardk2v1n1n1 extends Act {} {
	baseName = Reshard
	params = (P0->k2 + P1->v1 + P2->n1 + P3->n1)
}
one sig Reshardk1v1n2n1 extends Act {} {
	baseName = Reshard
	params = (P0->k1 + P1->v1 + P2->n2 + P3->n1)
}
one sig Reshardk2v2n2n1 extends Act {} {
	baseName = Reshard
	params = (P0->k2 + P1->v2 + P2->n2 + P3->n1)
}
one sig Reshardk2v1n1n2 extends Act {} {
	baseName = Reshard
	params = (P0->k2 + P1->v1 + P2->n1 + P3->n2)
}
one sig Reshardk1v1n2n2 extends Act {} {
	baseName = Reshard
	params = (P0->k1 + P1->v1 + P2->n2 + P3->n2)
}
one sig Reshardk2v2n2n2 extends Act {} {
	baseName = Reshard
	params = (P0->k2 + P1->v2 + P2->n2 + P3->n2)
}
one sig Reshardk1v2n2n1 extends Act {} {
	baseName = Reshard
	params = (P0->k1 + P1->v2 + P2->n2 + P3->n1)
}
one sig Reshardk1v1n1n1 extends Act {} {
	baseName = Reshard
	params = (P0->k1 + P1->v1 + P2->n1 + P3->n1)
}
one sig Reshardk2v2n1n1 extends Act {} {
	baseName = Reshard
	params = (P0->k2 + P1->v2 + P2->n1 + P3->n1)
}
one sig Reshardk1v2n2n2 extends Act {} {
	baseName = Reshard
	params = (P0->k1 + P1->v2 + P2->n2 + P3->n2)
}
one sig Reshardk1v1n1n2 extends Act {} {
	baseName = Reshard
	params = (P0->k1 + P1->v1 + P2->n1 + P3->n2)
}
one sig Reshardk2v2n1n2 extends Act {} {
	baseName = Reshard
	params = (P0->k2 + P1->v2 + P2->n1 + P3->n2)
}
one sig Reshardk1v2n1n1 extends Act {} {
	baseName = Reshard
	params = (P0->k1 + P1->v2 + P2->n1 + P3->n1)
}
one sig Reshardk1v2n1n2 extends Act {} {
	baseName = Reshard
	params = (P0->k1 + P1->v2 + P2->n1 + P3->n2)
}

one sig Put extends BaseName {} {
	maxParam = P2
}
one sig Putn1k2v1 extends Act {} {
	baseName = Put
	params = (P0->n1 + P1->k2 + P2->v1)
}
one sig Putn1k2v2 extends Act {} {
	baseName = Put
	params = (P0->n1 + P1->k2 + P2->v2)
}
one sig Putn1k1v1 extends Act {} {
	baseName = Put
	params = (P0->n1 + P1->k1 + P2->v1)
}
one sig Putn2k2v1 extends Act {} {
	baseName = Put
	params = (P0->n2 + P1->k2 + P2->v1)
}
one sig Putn2k1v1 extends Act {} {
	baseName = Put
	params = (P0->n2 + P1->k1 + P2->v1)
}
one sig Putn1k1v2 extends Act {} {
	baseName = Put
	params = (P0->n1 + P1->k1 + P2->v2)
}
one sig Putn2k2v2 extends Act {} {
	baseName = Put
	params = (P0->n2 + P1->k2 + P2->v2)
}
one sig Putn2k1v2 extends Act {} {
	baseName = Put
	params = (P0->n2 + P1->k1 + P2->v2)
}


one sig T0, T1, T2, T3 extends Idx {}

fact {
	IdxOrder/first = T0
	IdxOrder/next = T0->T1 + T1->T2 + T2->T3
	no OnceVar.baseName & Put
}


one sig var2, var1, var0 extends Var {} {}


one sig var0tov1var1ton1var2ton1 extends Env {} {
	maps = var0->v1 + var1->n1 + var2->n1
}
one sig var0tov2var1ton1var2ton1 extends Env {} {
	maps = var0->v2 + var1->n1 + var2->n1
}
one sig var0tov1var1ton2var2ton1 extends Env {} {
	maps = var0->v1 + var1->n2 + var2->n1
}
one sig var0tov1 extends Env {} {
	maps = var0->v1
}
one sig var0tov1var2ton2var1ton1 extends Env {} {
	maps = var0->v1 + var2->n2 + var1->n1
}
one sig var1ton2var0tov2var2ton1 extends Env {} {
	maps = var1->n2 + var0->v2 + var2->n1
}
one sig var0tov2 extends Env {} {
	maps = var0->v2
}
one sig var2ton2var0tov2var1ton1 extends Env {} {
	maps = var2->n2 + var0->v2 + var1->n1
}
one sig var0tov1var1ton2var2ton2 extends Env {} {
	maps = var0->v1 + var1->n2 + var2->n2
}
one sig var1ton2var0tov2 extends Env {} {
	maps = var1->n2 + var0->v2
}
one sig var0tov2var1ton1 extends Env {} {
	maps = var0->v2 + var1->n1
}
one sig var0tov1var1ton2 extends Env {} {
	maps = var0->v1 + var1->n2
}
one sig var1ton2var2ton2var0tov2 extends Env {} {
	maps = var1->n2 + var2->n2 + var0->v2
}
one sig var0tov1var1ton1 extends Env {} {
	maps = var0->v1 + var1->n1
}


one sig NT extends NegTrace {} {
  lastIdx = T1
  path = (T0->RecvTransferMsgn1k1v1 + T1->RecvTransferMsgn2k1v2)
}

one sig PT1 extends PosTrace {} {
  lastIdx = T3
  path = (T0->Putn2k1v2 + T1->Reshardk1v2n2n2 + T2->Putn1k2v2 + T3->RecvTransferMsgn2k1v2)
}
