use crate::self_model::SelfModel;

#[derive(Clone, Debug)]
pub struct Params {
    pub alpha: f64,
    pub beta: f64,
}

/// Derive Cobb-Douglas preference parameters from an agent's self-model.
/// raw_alpha = 2^hunger, raw_beta = 2^greed * 0.5
/// alpha = raw_alpha / (raw_alpha + raw_beta), beta = 1 - alpha
pub fn derive_params(sm: &SelfModel) -> Params {
    let raw_alpha = (2.0_f64).powf(sm.hunger.current);
    let raw_beta = (2.0_f64).powf(sm.greed) * 0.5;
    let total = raw_alpha + raw_beta;
    if total == 0.0 {
        return Params { alpha: 0.5, beta: 0.5 };
    }
    let alpha = raw_alpha / total;
    Params { alpha, beta: 1.0 - alpha }
}

/// U(food, gold) = (food+1)^alpha * (gold+1)^beta
pub fn utility(food: f64, gold: f64, p: &Params) -> f64 {
    (food + 1.0).powf(p.alpha) * (gold + 1.0).powf(p.beta)
}

/// dU/dF = alpha * (food+1)^(alpha-1) * (gold+1)^beta
pub fn marginal_utility_food(food: f64, gold: f64, p: &Params) -> f64 {
    p.alpha * (food + 1.0).powf(p.alpha - 1.0) * (gold + 1.0).powf(p.beta)
}

/// dU/dG = (food+1)^alpha * beta * (gold+1)^(beta-1)
pub fn marginal_utility_gold(food: f64, gold: f64, p: &Params) -> f64 {
    (food + 1.0).powf(p.alpha) * p.beta * (gold + 1.0).powf(p.beta - 1.0)
}

/// MRS = (alpha / beta) * ((gold+1) / (food+1))
/// Amount of gold willing to give up per unit of food.
pub fn mrs(food: f64, gold: f64, p: &Params) -> f64 {
    if p.beta == 0.0 {
        return f64::INFINITY;
    }
    (p.alpha / p.beta) * ((gold + 1.0) / (food + 1.0))
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::self_model::{Hunger, SelfModel};

    fn sm(hunger: f64, greed: f64) -> SelfModel {
        SelfModel {
            hunger: Hunger { current: hunger, max: 10.0 },
            greed,
        }
    }

    #[test]
    fn params_sum_to_one() {
        let p = derive_params(&sm(2.0, 1.0));
        assert!((p.alpha + p.beta - 1.0).abs() < 1e-10);
    }

    #[test]
    fn utility_positive_at_zero() {
        let p = derive_params(&sm(0.0, 0.0));
        assert!(utility(0.0, 0.0, &p) > 0.0);
    }

    #[test]
    fn high_hunger_increases_alpha() {
        let p_hungry = derive_params(&sm(8.0, 1.0));
        let p_full = derive_params(&sm(0.0, 1.0));
        assert!(p_hungry.alpha > p_full.alpha);
    }

    #[test]
    fn mrs_monotone_in_gold() {
        let p = derive_params(&sm(1.0, 1.0));
        let mrs_low = mrs(5.0, 1.0, &p);
        let mrs_high = mrs(5.0, 10.0, &p);
        assert!(mrs_high > mrs_low);
    }
}
